import strutils, sequtils, macros, algorithm
import math
static:
    const MAX_VEC_SIZE:int = 4
type
    Vec1[T]= distinct array[1,T]
    Vec2[T]= distinct array[2,T]
    Vec3[T]= distinct array[3,T]
    Vec4[T]= distinct array[4,T]

proc `$`*[T](a:openArray[T]):string=
    var 
        strs:seq[string] = @[]
    for i in a:
        strs.add( $i);
    return [ "[" ,strs.join(", "),"]" ].join
proc zipWith[I,F,T](a, b:array[I,F], op:proc(a,b:F):T):array[I,T]=
    for i in low(a) .. high(a):
        result[i] = op(a[i],b[i])
template toA( v:expr, i:int, T:typedesc):expr=
    array[i,T](v)

macro mkMathPerComponent():stmt=
    let ops = ['+', '-', '/', '*']
    result = newNimNode(nnkStmtList);
    for i in 1..MAX_VEC_SIZE:
        for op in ops:
            var str:string = "proc `$1`[T](v,u:$2[T]):$2[T]= $2(zipWith( v.toA($3,T), u.toA($3,T), proc(a,b:T):T=a$1b))"%[$op, "Vec$#"%[$i], $i]
            result.add(parseStmt(str ))

macro mkToStr():stmt=
    result = newNimNode(nnkStmtList);
    for i in 1..MAX_VEC_SIZE:
        result.add(parseStmt("proc `$$`[T](v:Vec$1[T]):string=  $$ array[$1, T](v)" % [ $i ]))

macro arrSetters():stmt=
    result = newNimNode(nnkStmtList);
    for i in 1..MAX_VEC_SIZE:
        result.add(parseStmt("proc `[]=`[T](v:Vec$1[T], ix:int, c:T) = array[$1,T](v)[ix]=c" % [$i] ))

macro arrGetters():stmt=
    result = newNimNode(nnkStmtList);
    for i in 1..MAX_VEC_SIZE:
        result.add(parseStmt("proc `[]`[T](v:Vec$1[T], ix:int):T = array[$1,T](v)[ix]" % [$i] ))

macro componentGetterSetters():stmt=
    result = newNimNode(nnkStmtList);
    let templG = "proc $1[T](v:Vec$2[T]):T=array[$2,T](v)[$3]"
    let templS = "proc `$1=`[T](v:var Vec$2[T],c:T)=(array[$2,T](v))[$3]=c"
    let tr = ["x","y","z","w"]
    let col= ["r","g","b","a"]
    for i in low(tr)..high(tr):
        for s in 1..MAX_VEC_SIZE:
            if i<s:
                result.add(parseStmt( templS % [tr[i], $s, $i] ))
                result.add(parseStmt( templG % [tr[i], $s, $i] ))
                result.add(parseStmt( templS % [col[i], $s, $i] ))
                result.add(parseStmt( templG % [col[i], $s, $i] ))
proc pow(a,b:int):int= floor(pow(a.float, b.float)).int
proc fmod(a,b:int):int=floor(fmod(a.float, b.float)).int
iterator shifts(minArr,arrLen:int):seq[int]=
    for S in minArr..MAX_VEC_SIZE:
        var totCombInLoop = pow(arrLen,S) # Total combinations for alphabet length = arrLen and  selection size = S
        #echo("Collections:", totCombInLoop)
        for j in 0..totCombInLoop-1:
            var cs:seq[int] = @[]
            for i in 1..S:
                #echo("$#/$#/$#"%[$j, $(j.fmod(pow(arrLen,i))), $(pow(arrLen,i-1) )])
                cs.add( floor(j.fmod( pow(arrLen,i) )/pow(arrLen,i-1) ).int )
            yield cs

macro multiComponentGetterList():stmt=
    result = newNimNode(nnkStmtList);
    let comps=["x","y","z","w"]
    for i in 2..MAX_VEC_SIZE:
        for combination in shifts(2,i):
            var getter:seq[string] = @[]
            var arr:seq[string] = @[]
            for c in combination:
                getter.add(comps[c])
                arr.add("v.$1"% comps[c])
            var procStr = "proc $1[T](v: Vec$2[T]):Vec$3[T]=Vec$3[T]([$4])" % [getter.join(""), $i, $combination.len, arr.join(",")]
            result.add(parseStmt( procStr))

        
proc getComponentIx(shiftn,length,componentIx:int):int=
    floor(shiftn.fmod( pow(length,componentIx) )/pow(length,componentIx-1) ).int
    
proc shifts(data:seq[char]):seq[seq[char]]=
    
    var length = data.len;
    var shifts = pow(length, length)
    result = @[]
    
    for i in 0..shifts-1:
        var cs:seq[char] = @[]
        for j in 1..length:
            cs.add( data[getComponentIx(i, length, j)] )
        result.add(cs)

proc flatten[T](s:seq[seq[T]]):seq[T]=
    result = @[]
    for i in s:
        result = result &i
proc getCombinationsForLength(l:int):seq[seq[char]]=
    var vx:seq[char] = @['V']
    for i in 1..MAX_VEC_SIZE:
        var c:char = ($i)[0]
        vx.add(c)
    proc glength(s:char):int=
        case s
        of 'V', '1': result=1
        else: result = parseInt($s)
    var available = vx.filter(proc(x:char):bool=return glength(x) <= l)
    result = @[]
    var count = 0;
    for sym in available.reversed():
        var res:seq[char] = @[ sym ]
        count += glength(sym)
        if count < l:
            var newSymbols = getCombinationsForLength(l - count)
            for s in newSymbols:
                var nres = res.concat(s)
                result.add(nres)
            count =0
        else:
            count = 0
            result.add(res);

proc componentGetters(c:char, sm:string):seq[string]=
    case c
    of 'V': result = @[sm]
    else:
        result = @[]
        var size = parseInt($c) 
        for i in 0..size-1:
            result.add("$1[$2]" % [ sm, $i])


proc parameterConstructor(c:char, sm:string):seq[string]=
    case c
    of 'V': result = @["$1:T" % [sm] ]
    else:
        result = @[]
        var size = parseInt($c)
        result.add("$1:Vec$2[T]" % [sm, $size ])


macro createConstructors():stmt =
    result = newNimNode(nnkStmtList);
    let paramnames = "abcdefghijklomnpo"
    for vl in 1..MAX_VEC_SIZE:
        var procStr = "proc vec$1*[$4]($2):Vec$1[$4]=Vec$1([$3])"
        var procStrU = "proc vec$1*($2):Vec$1[$4]=Vec$1([$3])"
        # create empty constructor
        var resultProc = procStrU % [$vl, "", repeat(@["0.0"],vl).join(", "), "float" ]
        echo resultProc
        result.add(parseStmt(resultProc))
        # create one parameter constructor
        if(vl > 1):
            resultProc = procStr % [$vl, "a:T", repeat(@["a"],vl).join(", "), "T" ]
            echo resultProc
            result.add(parseStmt(resultProc))
        for combination in getCombinationsForLength(vl):
            var arrayConstructor:seq[string] = @[]
            var parameterConstructor:seq[string] = @[]
            for ix in combination.low..combination.high:
                for cg in componentGetters(combination[ix], $(paramnames[ix])):
                    arrayConstructor.add(cg)
                for pc in parameterConstructor(combination[ix], $(paramnames[ix])):
                    parameterConstructor.add(pc)
            var resultProc = procStr % [
                $vl,
                parameterConstructor.join(", "),
                arrayConstructor.join(", "),
                "T"
            ]
            echo resultProc
            result.add(parseStmt( resultProc) )




mkToStr()
mkMathPerComponent()
arrGetters()
arrSetters()
componentGetterSetters()
multiComponentGetterList()
createConstructors()
    