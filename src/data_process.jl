module data_process

using RDatasets, DataFrames, CSV
using CategoricalArrays
using Clustering
using Random
using LinearAlgebra
using kcenter_opt

export data_preprocess, cluster_eval, plotResult, sig_gen

# function for data pre-processing, here missingchar will be a single character
function data_preprocess(dataname, datapackage = "datasets", path=nothing, missingchar=nothing, header=false, types=Float64)
    # read data
    if path === nothing # read data from r-package datasets
        data = dataset(datapackage, dataname)
    elseif missingchar === nothing
        println(joinpath(path, dataname))
        data = CSV.read(joinpath(path, dataname), DataFrame, header = header)
    else
        data = CSV.read(joinpath(path, dataname), DataFrame, header = header, types= types, missingstring = missingchar)
        data = dropmissing(data)
    end

    if dataname == "iris"
        return Array(Matrix(data[:, 1:(ncol(data)-1)])') # delete the label column in iris
    else
        return Array(Matrix(data[:, 1:(ncol(data))])')
    end
end 

function sig_gen(eigvals)
    n = length(eigvals)
    Q, ~ = qr(randn(n, n))
    D = Diagonal(eigvals) 
    return Q*D*Q'
end


# function to update the centers during kmeans, 
# here it is used to calculate the real center of the dataset
function update_centers(X, assign, k)
    d, n = size(X)
    centers = zeros(d, k)
    wcounts = zeros(k)

    for j in 1:n
        cj = assign[j]
        for i in 1:d
            centers[i, cj] += X[i, j]
        end
	wcounts[cj] += 1
    end

    for j in 1:k
        cj = wcounts[j]
        for i in 1:d
            centers[i, j] /= cj
        end
    end
    return centers
end


# function to get the real centers and cost, slower than update_centers 
function get_center_cost(X, assign, k)
    d, n = size(X)
    centers = zeros(d, k)
    cost = 0
    for i in 1:k
        ci = X[:,findall(x->x==i, assign)]
        centers[:,i] = mapslices(mean, ci; dims=2)
        cost += sum(sum((ci[:,j].-centers[:,i]).^2 for j in 1:size(ci)[2]))
    end

    return centers, cost
end


# function for ploting result graphs
function plotResult(result, dataname)
    initLB = result[2][4]-25
    initUB = result[2][5]+25
    result[1][4:5] = [initLB initUB] # here to draw clearly, put +/- 50 for inital LB/UB
    pRlt = hcat(deleteat!(result, length(result))...) # 6*number of iterations
    plt = Plots.plot(pRlt[1,:], pRlt[4:5,:]', #title="Lower and Upper Bound for Each Iterations", 
        label=["Lower Bound" "Upper Bound"], lw=2)
    gap = round(result[end][end], digits=5)
    savefig(plt, "pic/$dataname-ub_lb_crv$gap.png")
end


# normalized mutual information
function compute_nmi(z1::Array{Int64,1}, z2::Array{Int64,1})
    n = length(z1)
    k1 = length(unique(z1))
    k2 = length(unique(z2))

    nk1 = zeros(k1,1)
    nk2 = zeros(k2,1)

    for (idx,val) in enumerate(unique(z1))
        cluster_idx = findall(z1->z1 == val, z1)
        nk1[idx] = length(cluster_idx)
    end

    for (idx,val) in enumerate(unique(z2))
        cluster_idx = findall(z2->z2 == val, z2)
        nk2[idx] = length(cluster_idx)
    end

    pk1 = nk1/float(sum(nk1))
    pk2 = nk2/float(sum(nk2))

    nk12 = zeros(k1,k2)
    for (idx1, val1) in enumerate(unique(z1))
        for (idx2, val2) in enumerate(unique(z2))
            cluster_idx1 = findall(z1->z1 == val1, z1)
            cluster_idx2 = findall(z2->z2 == val2, z2)
            common_idx12 = intersect(Set(cluster_idx1), Set(cluster_idx2))
            nk12[idx1,idx2] = length(common_idx12)
        end
    end
    pk12 = nk12/float(n) 
 
    Hx = -sum(pk1.*log.(pk1.+eps(Float64)))
    Hy = -sum(pk2.*log.(pk2.+eps(Float64)))
    Hxy = -sum(pk12.*log.(pk12.+eps(Float64)))

    MI = Hx + Hy - Hxy
    return MI/float(0.5*(Hx+Hy))
end


# clustering evaluation criteria: 
# NMI, varation of information, rand index
function cluster_eval(z1::Array{Int64,1}, z2::Array{Int64,1})
    K1 = length(unique(z1))
    K2 = length(unique(z2))

    #normalized MI
    nmi = compute_nmi(z1,z2)
    println("nmi: ", nmi)

    #variation of information
    vi = Clustering.varinfo(K1, z1, K2, z2)
    println("vi: ", vi)

    #adjusted rand index
    ari = randindex(z1,z2)
    println("ari: ", ari[1])

    return nmi, vi, ari
end


end