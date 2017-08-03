type ImplicitRHS_Scalar{F,uType,tType} <: Function
  f::F
  C::uType
  a::tType
  t::tType
  dt::tType
end

function (p::ImplicitRHS_Scalar)(u,resid)
  resid[1] = first(u) .- first(p.C) .- p.a.*first(p.f(p.t+p.dt,first(u)))
end

type ImplicitRHS{F,uType,tType,DiffCacheType} <: Function
  f::F
  C::uType
  a::tType
  t::tType
  dt::tType
  dual_cache::DiffCacheType
end

function (p::ImplicitRHS)(u,resid)
  du1 = get_du(p.dual_cache, eltype(u))
  p.f(p.t+p.dt,reshape(u,size(du1)),du1)
  vecdu1 = vec(du1)
  @. resid = u - p.C - p.a*vecdu1
end

@inline function initialize!(integrator,cache::GenericImplicitEulerConstantCache,f=integrator.f)
  cache.uhold[1] = integrator.uprev; cache.C[1] = integrator.uprev
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.fsalfirst = f(integrator.t,integrator.uprev)

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@inline function perform_step!(integrator,cache::GenericImplicitEulerConstantCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  @unpack uhold,C,rhs,nl_rhs = cache
  C[1] = uhold[1]
  if integrator.iter > 1 && !integrator.u_modified
    uhold[1] = current_extrapolant(t+dt,integrator)
  end # else uhold is previous value.
  rhs.t = t
  rhs.dt = dt
  rhs.a = dt
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  uhold[1] = nlres[1]
  k = f(t+dt,uhold[1])
  integrator.fsallast = k
  u = uhold[1]
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = k
  @pack integrator = t,dt,u
end

@inline function initialize!(integrator,cache::GenericImplicitEulerCache,f=integrator.f)
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  f(integrator.t,integrator.uprev,integrator.fsalfirst)
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@inline function perform_step!(integrator,cache::GenericImplicitEulerCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  uidx = eachindex(integrator.uprev)
  @unpack C,dual_cache,k,nl_rhs,rhs,uhold = cache
  copy!(C,uhold)
  if integrator.iter > 1 && !integrator.u_modified
    current_extrapolant!(u,t+dt,integrator)
  end # else uhold is previous value.
  rhs.t = t
  rhs.dt = dt
  rhs.a = dt
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  copy!(uhold,nlres)
  f(t+dt,u,k)
  @pack integrator = t,dt,u
end

@inline function initialize!(integrator,cache::GenericTrapezoidCache,f=integrator.f)
  @unpack k,fsalfirst = cache
  integrator.fsalfirst = fsalfirst
  integrator.fsallast = cache.k
  f(integrator.t,integrator.uprev,integrator.fsalfirst)
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@inline function perform_step!(integrator,cache::GenericTrapezoidCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  uidx = eachindex(integrator.uprev)
  @unpack C,dual_cache,k,rhs,nl_rhs,uhold = cache
  C .= uhold .+ (dt/2).*vec(integrator.fsalfirst)
  if integrator.iter > 1 && !integrator.u_modified
    current_extrapolant!(u,t+dt,integrator)
  end # else uhold is previous value.
  # copy!(rhs.fsalfirst,fsalfirst) Implicitly done by pointers: fsalfirst === fsalfirst == rhs.fsalfirst
  rhs.t = t
  rhs.dt = dt
  rhs.a = dt/2
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  copy!(uhold,nlres)
  f(t+dt,u,k)
  @pack integrator = t,dt,u
end

@inline function initialize!(integrator,cache::GenericTrapezoidConstantCache,f=integrator.f)
  cache.uhold[1] = integrator.uprev; cache.C[1] = integrator.uprev
  integrator.fsalfirst = f(integrator.t,integrator.uprev)
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@inline function perform_step!(integrator,cache::GenericTrapezoidConstantCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  @unpack uhold,C,rhs,nl_rhs = cache
  C[1] = first(uhold) + (dt/2)*first(integrator.fsalfirst)
  if integrator.iter > 1 && !integrator.u_modified
    uhold[1] = current_extrapolant(t+dt,integrator)
  end # else uhold is previous value.
  rhs.t = t
  rhs.dt = dt
  rhs.a = dt/2
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  uhold[1] = nlres[1]
  k = f(t+dt,uhold[1])
  integrator.fsallast = k
  u = uhold[1]
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  @pack integrator = t,dt,u
end