

function codegen(m::JointDistribution)
    return codegen(symlogpdf(m))    
end


export codegen
function codegen(s::Sym)
    s.func == sympy.Add && begin
        @gensym add
        ex = @q begin 
            $add = 0.0
        end
        for arg in s.args
            t = codegen(arg)
            push!(ex.args, :($add += $t))
        end
        push!(ex.args, add)
        # @show ex
        return ex
    end


    s.func == sympy.Mul && begin
        @gensym mul
        ex = @q begin 
            $mul = 1.0
        end
        for arg in s.args
            t = codegen(arg)
            push!(ex.args, :($mul *= $t))
        end
        push!(ex.args, mul)
        return ex
    end

    s.func ∈ keys(symfuncs) && begin
        # @show s
        @gensym symfunc
        argnames = gensym.("arg" .* string.(1:length(s.args)))
        argvals = codegen.(s.args)
        ex = @q begin end
        for (k,v) in zip(argnames, argvals)
            push!(ex.args, :($k = $v))
        end
        f = symfuncs[s.func]
        push!(ex.args, :($symfunc = $f($(argnames...))))
        push!(ex.args, symfunc)
        return ex
    end

    s.func == sympy.Sum && begin
        @gensym sum
        @gensym Δsum
        @gensym lo 
        @gensym hi
        
        summand = codegen(s.args[1])

        ex = @q begin
                    $Δsum = $summand
                    $sum += $Δsum
        end
        
        for limits in s.args[2:end]
            (ix, ixlo, ixhi) = limits.args

            ex = @q begin
                $lo = $(codegen(ixlo))
                $hi = $(codegen(ixhi))
                for $(codegen(ix)) in $lo:$hi
                    $Δsum = $summand
                    $sum += $Δsum
                end
            end
        end
        
        ex = @q begin
            let 
                $sum = 0.0
                $ex
            $sum
            end
        end

        return ex |> flatten
    end
    
    s.func == sympy.Symbol && return Symbol(string(s))
    s.func == sympy.Idx && return Symbol(string(s))        
    s.func == sympy.IndexedBase && return Symbol(string(s))

    # @show s
    return convert(Expr, s)
end


# julia> codegen(sym(:x) + sym(:y))
# quote
#     var"##add#407" = 0.0
#     var"##add#407" += x
#     var"##add#407" += y
#     var"##add#407"
# end