package lib.ha.core.utils;

import haxe.CallStack;
class Debug
{
    public static function brk()
    {
        try
        {
            throw "__dummy__";
        }
        catch(ex: String)
        {

        }
    }

    public inline static function caller(): String
    {
        var stack = CallStack.callStack();
        if (stack.length < 3)
        {
            return "";
        }

        return '${stack[1]}';
    }
}