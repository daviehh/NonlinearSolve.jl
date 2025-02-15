using NonlinearSolve, LinearAlgebra, SparseArrays, Symbolics

const N = 32
const xyd_brusselator = range(0, stop = 1, length = N)
brusselator_f(x, y) = (((x - 0.3)^2 + (y - 0.6)^2) <= 0.1^2) * 5.0
limit(a, N) = a == N + 1 ? 1 : a == 0 ? N : a
function brusselator_2d_loop(du, u, p)
    A, B, alpha, dx = p
    alpha = alpha / dx^2
    @inbounds for I in CartesianIndices((N, N))
        i, j = Tuple(I)
        x, y = xyd_brusselator[I[1]], xyd_brusselator[I[2]]
        ip1, im1, jp1, jm1 = limit(i + 1, N), limit(i - 1, N), limit(j + 1, N),
                             limit(j - 1, N)
        du[i, j, 1] = alpha * (u[im1, j, 1] + u[ip1, j, 1] + u[i, jp1, 1] + u[i, jm1, 1] -
                       4u[i, j, 1]) +
                      B + u[i, j, 1]^2 * u[i, j, 2] - (A + 1) * u[i, j, 1] +
                      brusselator_f(x, y)
        du[i, j, 2] = alpha * (u[im1, j, 2] + u[ip1, j, 2] + u[i, jp1, 2] + u[i, jm1, 2] -
                       4u[i, j, 2]) +
                      A * u[i, j, 1] - u[i, j, 1]^2 * u[i, j, 2]
    end
end
p = (3.4, 1.0, 10.0, step(xyd_brusselator))

function init_brusselator_2d(xyd)
    N = length(xyd)
    u = zeros(N, N, 2)
    for I in CartesianIndices((N, N))
        x = xyd[I[1]]
        y = xyd[I[2]]
        u[I, 1] = 22 * (y * (1 - y))^(3 / 2)
        u[I, 2] = 27 * (x * (1 - x))^(3 / 2)
    end
    u
end
u0 = init_brusselator_2d(xyd_brusselator)
prob_brusselator_2d = NonlinearProblem(brusselator_2d_loop, u0, p)
sol = solve(prob_brusselator_2d, NewtonRaphson())

du0 = copy(u0)
jac_sparsity = Symbolics.jacobian_sparsity((du, u) -> brusselator_2d_loop(du, u, p), du0,
                                           u0)

ff = NonlinearFunction(brusselator_2d_loop; jac_prototype = float.(jac_sparsity))
prob_brusselator_2d = NonlinearProblem(ff, u0, p)
sol = solve(prob_brusselator_2d, NewtonRaphson())
@test norm(sol.resid) < 1e-8

sol = solve(prob_brusselator_2d, NewtonRaphson(autodiff = false))
@test norm(sol.resid) < 1e-6

cache = init(prob_brusselator_2d, NewtonRaphson())
@test maximum(cache.jac_config.colorvec) == 12
