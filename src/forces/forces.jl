"""
# sum_force
This function computes the sum of the forces acting on each point in a set of points. The force on a point is computed by iterating over each other 
point and calculating the force according to some force function. Additionally, a contractile force is added between each point and its nearest 
neighbor. 
    
    The inputs to the function are:

        • idx       : An array of indices indicating which points are neighbors of each other point.
        • idx_cont  : An array of indices indicating the nearest neighbor of each point.
        • points    : An array of the positions of the points.
        • force     : An array to store the computed forces.
        • force_par : Parameters for the force function.
        • cont_par  : Parameters for the contractile force.
        • t_knn     : Time index for the nearest neighbor calculation.

The function uses CUDA to parallelize the computation across multiple threads and blocks. The function defines two indices (i and k) 
to keep track of the point and the dimension being computed. Inside the kernel, the function computes the force on each point by iterating 
over each other point and checking if it is a neighbor. If it is a neighbor, it calculates the force according to some force function and adds 
it to the total force on the point. After iterating over all neighbors, the function adds a contractile force between the point and its nearest neighbor.
Finally, the function writes the computed force to the output array force.
"""
function sum_force!(idx,idx_cont,points,force,force_par,cont_par,t_knn)
    # Defining Index for kernel
    i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    k = (blockIdx().y - 1) * blockDim().y + threadIdx().y

    # Limiting data inside matrix
    if i <= size(points, 1) && k <= size(points, 2)

        # Cleaning idx_sum
        force[i,k] = 0
        dist = 0

        # Iterate on each row
        for j=1:size(idx,1)

            # Finding forces
            if idx[j,i] != i && idx[j,i] != 0
                dist = euclidean(points,i,idx[j,i])
                force[i,k] += force_func(force_par,i,dist) * (points[i,k]-points[idx[j,i],k]) / dist
            end
            
        end

        # Adding Contrractile Force
        if idx_cont[t_knn,i] != i && idx_cont[t_knn,i] != 0
            dist = euclidean(points,i,idx_cont[t_knn,i])
            force[i,k] += cont_par[i]*(points[i,k]-points[idx_cont[t_knn,i],k])/dist
        end
        
    end
    return nothing
end

"""
# cu_force

Compute the forces between each pair of particles in `agg`.

    The inputs to the function are:
        • agg   : Aggregate : The aggregate for which to compute the forces.
        • t_knn : int       : The time step at which to apply the contractile force.
"""
function cu_force(agg::Aggregate,t_knn)
    # GPU requirements
    threads =(100,3)
    blocks  =(cld.(size(agg.Position,1)+1,threads[1]),1)

    # Running GPU kernel
    @cuda threads=threads blocks=blocks sum_force!(
        agg.Simulation.Neighbor.idx_red,
        agg.Simulation.Neighbor.idx_cont,
        agg.Position,
        agg.Simulation.Force.F,
        agg.Simulation.Parameter.Force,
        agg.Simulation.Parameter.Contractile.fₚ,
        Int(t_knn)
    )
end

################################ NEW ####################################
# using LinearAlgebra: norm
# using NearestNeighbors
# using Shuffle

# function cpu_force(X, idxs, r_max, fp, K )
#     # Initialise displacement array
#     global dX = zeros(Float64, size(X)[1], 3)

#     for i in 1:size(X)[1]
#         # Initialise variables
#         global Xi = X[i,1:3]
#         for j in idxs[:,i]
#             if i != j
#                 global r = Xi - X[j,:]
#                 global dist = norm(r)
#                 # Calculate attraction/repulsion force differential here
#                 if dist < r_max
#                     global F = - K*(dist-r_max)*(dist-r_max)*(dist - s)
#                     dX[i,:] =  dX[i,:] + r/dist * F
#                 end 
#             end
#         end
#     end
#     return dX
# end

# function cu_force(t::Time, c::Contractile, Agg::Aggregate)
#     # Definig Variables for calculing dX
#     global Agg

#     # Calculating distance for random forces (contractile)
#     Agg.Force.r_p = Agg.Position.X .- 
#                         Agg.Position.X[
#                             Agg.Neighbor.rand_idx[
#                                 Int.(mod(
#                                     Agg.t, size(Agg.Position.X, 1)
#                                 ) .+ 1),
#                             :],
#                         :]
    
#     # Finding Distances/Norm for random forces
#     Agg.Force.dist_p = sum(Agg.Force.r_p .^ 2, dims=2).^ 0.5

#     # Finding distances
#     Agg.Force.r = reshape(
#             repeat(Agg.Position.X, inner=(Agg.ParNeighbor.nn,1)), 
#             Agg.ParNeighbor.nn, size(Agg.Position.X)[1], 3
#         ) .- 
#         Agg.Position.X[getindex.(Agg.Neighbor.idx,1),:]

#     # Finding Distances(Norm)
#     Agg.Force.dist = ((sum(Agg.Force.r .^ 2, dims=3)) .^ 0.5)[:,:,1]

#     # # Finding forces for each cell
#     Agg.Force.F = force(Agg.Force.dist) .* Agg.Force.r ./ Agg.Force.dist

#     # # Calculating de dX   -> dX[i,:] +=  r/dist * F
#     Agg.Position.dX = sum(Agg.Force.F[2:end,:,:]; dims=1)[1,:,:] -                                       
#                         c.fₚ .* (Agg.Force.r_p ./ Agg.Force.dist_p)
#     synchronize()
# end