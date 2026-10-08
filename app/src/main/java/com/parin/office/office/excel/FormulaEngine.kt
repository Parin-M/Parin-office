package com.parin.office.office.excel

import kotlin.math.*

sealed interface Value {
    data class Number(val value:Double):Value
    data class Text(val value:String):Value
    data object Blank:Value
    data class Error(val message:String):Value
}

class FormulaEngine(
    private val cellProvider:(String)->Value = { Value.Blank }
){
    fun evaluate(input:String):Value{
        val formula=input.trim().removePrefix("=")
        if(formula.isBlank()) return Value.Blank
        return runCatching{Parser(formula).parseExpression()}.getOrElse{Value.Error(it.message ?: "#ERROR!")}
    }

    private inner class Parser(private val s:String){
        private var pos=0
        fun parseExpression():Value{
            var left=parseTerm()
            while(true){
                skip()
                if(match('+')) left=number(left)+number(parseTerm())
                else if(match('-')) left=number(left)-number(parseTerm())
                else return left
            }
        }
        private fun parseTerm():Value{
            var left=parseFactor()
            while(true){
                skip()
                if(match('*')) left=number(left)*number(parseFactor())
                else if(match('/')) {
                    val r=number(parseFactor()).value
                    if(r==0.0) return Value.Error("#DIV/0!")
                    left=Value.Number(number(left).value/r)
                } else return left
            }
        }
        private fun parseFactor():Value{
            skip()
            if(match('(')){val v=parseExpression();expect(')');return v}
            if(peekDigit()||peek()=='.'||peek()=='-'){
                val start=pos
                if(peek()=='-')pos++
                while(peekDigit()||peek()=='.')pos++
                return Value.Number(s.substring(start,pos).toDouble())
            }
            val start=pos
            while(peek()?.isLetterOrDigit()==true||peek()=='_'||peek()=='$')pos++
            val token=s.substring(start,pos)
            if(token.isBlank()) error("Unexpected token")
            skip()
            if(match('(')){
                val args=mutableListOf<Value>()
                skip()
                if(!match(')')){
                    while(true){
                        args+=parseExpression()
                        skip()
                        if(match(')'))break
                        expect(',')
                    }
                }
                return function(token,args)
            }
            return cellProvider(token)
        }
        private fun function(name:String,args:List<Value>):Value{
            val n=args.mapNotNull{(it as? Value.Number)?.value}
            return when(name.uppercase()){
                "SUM"->Value.Number(n.sum())
                "AVERAGE"->if(n.isEmpty())Value.Error("#DIV/0!") else Value.Number(n.average())
                "MIN"->if(n.isEmpty())Value.Error("#VALUE!") else Value.Number(n.min())
                "MAX"->if(n.isEmpty())Value.Error("#VALUE!") else Value.Number(n.max())
                "ABS"->Value.Number(abs(n.firstOrNull()?:0.0))
                "ROUND"->Value.Number(round(n.getOrNull(0)?:0.0))
                "SQRT"->Value.Number(sqrt(n.firstOrNull()?:0.0))
                else->Value.Error("#NAME?")
            }
        }
        private fun number(v:Value)=v as? Value.Number ?: error("#VALUE!")
        private operator fun Value.Number.plus(v:Value.Number)=Value.Number(value+v.value)
        private operator fun Value.Number.minus(v:Value.Number)=Value.Number(value-v.value)
        private operator fun Value.Number.times(v:Value.Number)=Value.Number(value*v.value)
        private fun skip(){while(peek()?.isWhitespace()==true)pos++}
        private fun match(ch:Char):Boolean{skip();if(peek()==ch){pos++;return true};return false}
        private fun expect(ch:Char){if(!match(ch))error("Expected $ch")}
        private fun peekDigit()=peek()?.isDigit()==true
        private fun peek():Char?=s.getOrNull(pos)
    }
}
