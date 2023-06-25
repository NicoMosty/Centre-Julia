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
The function writes the computed force to the output array force. Finally, the position of each point is updated based on the total force acting on that 
point and the time step.
"""
function rand_to_angle()
    return (acos(2*rand()-1),2*pi*(2*rand()-1),1)
end
function angle_to_pol(pol,i)
    x = sin(pol[i,1])*cos(pol[i,2])
    y = sin(pol[i,1])*sin(pol[i,2])
    z = cos(pol[i,1])
    return (x,y,z)
end
function sum_force!(points,force,pol,N_i,idx_sum,idx,force_par,cont_par,A,B,dt)
    # A -> Angle between parallel and pernedicular angle in force contractile
    # B -> Opening angle of the polarization ratio

    i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    k = (blockIdx().y - 1) * blockDim().y + threadIdx().y
    ti, tk = threadIdx().x, threadIdx().y 

    if i <= size(points, 1) && k <= size(points, 2)

        # Cleaning force
        force[i,k] = 0
        
        pol[i,1], pol[i,2], pol[i,3] = rand_to_angle()
        sync_threads()
        pol[i,1], pol[i,2], pol[i,3] = angle_to_pol(pol,i)
        sync_threads()

        # Iterate on each row
        for j=1:idx_sum[i]
        # for j=1:1
            if idx[j,i] != 0

                # # Finding norm and distances
                dist = euclidean(points,i,idx[j,i])
                norm = (points[i,k]-points[idx[j,i],k])/dist
                sync_threads()

                # Calculating forces on each cell
                if dist < force_par.rₘₐₓ[i]
                    force[i,k] += force_func(force_par,i,dist) * norm
                    sync_threads()
                end
                
                # Calculating angle between polarization vector and  ...
                N_i[i] = 0
                for m = 1:3
                    N_i[i] += (points[i,m]-points[idx[j,i],m])/dist * pol[i,m]
                    sync_threads()
                end

                if cos(B) <  N_i[i]
                #     <-------------------------------------------------------------------------------- THIS
                    force[i,k]         -= cont_par[i]*pol[i,k]
                    # force[i,k]         -= cont_par[i]*norm
                    sync_threads()
                    # force[idx[j,i],k]  -= cont_par[i]*pol[i,k]
                    # sync_threads()
                #     <-------------------------------------------------------------------------------- THIS
                    # force[i,k]        -= cont_par[i]*( 
                    #                             sin(A)/(sqrt(1-N_i[i]^2))*norm
                    #                         +  (cos(A) - sin(A)*N_i[i]/(sqrt(1-N_i[i]^2)))*pol[i,k]        
                    #                         )
                #     force[idx[j,i],k] -= cont_par[i]*( 
                #                                 sin(A)/(sqrt(1-N_i[ti]^2))*norm[ti,tk]  
                #                             +  (cos(A) - sin(A)*N_i[ti]/(sqrt(1-N_i[ti]^2)))*pol[i,k]        
                #                             )
                #     <-------------------------------------------------------------------------------- THIS
                end

            end
        end

        # <-------------------------------------------------------------------------------- THIS
        # Adding Contractile Force (Me without Area)
        
        # # Adding Contractile Force (Oriola without Area)
        # randomo[ti,tk] = rand(1:idx_sum[i])
        # force[i,k] = randomo[ti]

        # if randomo[ti] != i
        #     dist = euclidean(points,idx[randomo[ti],i],i)
        #     norm[ti,tk] = (points[i,k]-points[idx[randomo[ti],i],k])/dist
        #     force[i,k] -= cont_par[i]*norm[ti,tk]
        # end

        # Adding Contractile Force (Oriola without Area)
        # idx_cont[ti,tk] = rand_to_cont(i,idx,idx_sum)
        # if idx_cont[ti]  != i && idx_cont[ti]  != 0
        #     dist = euclidean(points,i,idx_cont[ti] )
        #     force[i,k] -= cont_par[i]*(points[i,k]-points[idx_cont[ti] ,k])/dist
        # end
        # <-------------------------------------------------------------------------------- THIS

        points[i,k] += force[i,k] * dt

    end

    return nothing

end

# function sum_force!(idx,idx_cont,idx_sum,points,force,force_par,cont_par,dt,t_knn,pol_mat)
#     # pol_mat
#     # Defining Index for kernel
#     i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
#     k = (blockIdx().y - 1) * blockDim().y + threadIdx().y

#     # Limiting data inside matrix
#     if i <= size(points, 1) && k <= size(points, 2)

#         # Cleaning force
#         force[i,k] = 0

#         # # Generating Polarization vector
#         phi = 2*pi*(2*rand() - 1)

#         pol_mat[i,3] = 2*rand() - 1
#         pol_mat[i,1] = sqrt(1-pol_mat[i,3]^2)*cos(phi)
#         pol_mat[i,2] = sqrt(1-pol_mat[i,3]^2)*sin(phi)

#         # Iterate on each row
#         # for j=1:size(idx,1)
#         for j=1:idx_sum[i]
#             # Finding forces
#             if idx[j,i] != 0
#                 dist = euclidean(points,idx[j,i],i)
#                 # if dist < force_par.rₘₐₓ[i]
#                 force[i,k] += force_func(force_par,i,dist) * (points[i,k]-points[idx[j,i],k])/dist
#                 # end
#                 # <------------------------------------------- THIS [Add Area Function]

#                 # <-------------------------------------------
#             end
#         end

#         # Adding Contractile Force (Me without Area)
#         force[i,k] += cont_par[i]*pol_mat[i,k]

#         # # Adding Contractile Force (Oriola without Area)
#         # if idx_cont[t_knn,i] != i && idx_cont[t_knn,i] != 0
#         #     dist = euclidean(points,i,idx_cont[t_knn,i])
#         #     force[i,k] -= cont_par[i]*(points[i,k]-points[idx_cont[t_knn,i],k])/dist
#         # end

#         # Summing dX on the position of the aggregate on a specific dt
#         points[i,k] = points[i,k] + force[i,k] * dt
        
#     end
#     return nothing
# end


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