// Atom.as
// https://github.com/maximgavrilov/atom-as3
// Author: Maxim Gavrilov (maxim.gavrilov@gmail.com)
// License: BSD
//
// inspired by
// https://github.com/zynga/atom
// Author: Chris Campbell (@quaelin)
// License: BSD


package {
public class Atom {
    private var nucleus:Nucleus;
    private var q:Q;

    public function Atom(...args) {
        nucleus = new Nucleus();
        q = new Q();

        if (args.length) {
            set.apply(null, args);
        }
    }

    public function chain(...args):Atom {
        q.chain.apply(null, args);
        return this;
    }

    public function destroy():void {
        nucleus.destroy();
        nucleus = null;

        q.destroy();
        q = null;
    }

    public function each(keyOrList:Object, func:Function):Atom {
        var keys:Array = Utils.toArray(keyOrList);
        var i:int = -1;
        var len:int = keys.length;
        while (++i < len) {
            var key:Object = keys[i];
            func(key, get(key));
        }
        return this;
    }

    public function entangle(otherAtom:Atom, keyOrListOrMap:Object):Atom {
        var isList:Boolean = keyOrListOrMap is Array;
        var isMap:Boolean = !isList && typeof(keyOrListOrMap) == 'object';
        var keys:Array = isList ? keyOrListOrMap as Array : (isMap ? [] : [keyOrListOrMap]);
        var map:Object = isMap ? keyOrListOrMap : {};
        var key:String;

        if (isMap) {
            for (key in map) {
                if (map.hasOwnProperty(key)) {
                    keys.push(key);
                }
            }
        } else {
            for (var i:int = keys.length; --i >= 0;) {
                key = keys[i];
                map[key] = key;
            }
        }
        each(keys, function (key:String, value:Object):void {
            var otherKey:String = map[key];
            on(key, function (value:Object):void {
                otherAtom.set(otherKey, value);
            });
            otherAtom.on(otherKey, function (value:Object):void {
                set(key, value);
            });
        });
        return this;
    }

    public function get(keyOrList:Object, func:Function = null):Object {
        var result:Result = nucleus.get(keyOrList, func);
        return (func != null) ? result : (keyOrList is String ? result.values[0] : result.values);
    }

    public function has(keyOrList:Object):Boolean {
        var props:Object = nucleus.props;
        var keys:Array = Utils.toArray(keyOrList);
        for (var i:int = keys.length; --i >= 0;) {
            if (!props.hasOwnProperty(keys[i])) {
                return false;
            }
        }
        return true;
    }

    public function keys():Array {
        var keys:Array = [];
        var props:Object = nucleus.props;
        for (var key:String in props) {
            if (props.hasOwnProperty(key)) {
                keys.push(key);
            }
        }
        return keys;
    }

    public function need(keyOrList:Object, func:Function = null):Atom {
        var keys:Array = Utils.toArray(keyOrList);
        var providers:Object = nucleus.providers;
        var props:Object = nucleus.props;
        var needs:Object = nucleus.needs;

        for (var i:int = keys.length; --i >= 0;) {
            var key:String = keys[i];
            var provider:Function = providers[key];
            if (!props.hasOwnProperty(key) && (provider != null)) {
                nucleus.provide(key, provider);
                delete providers[key];
            } else {
                needs[key] = true;
            }
        }
        if (func != null) {
            once(keys, func);
        }
        return this;
    }

    public function next(keyOrList:Object, func:Function):Atom {
        nucleus.listeners.unshift(new Listener(Utils.toArray(keyOrList), func, 1));
        return this;
    }

    public function off(keyOrList:Object, func:Function = null):Atom {
        if (func == null) {
            func = keyOrList as Function;
            keyOrList = null;
        }

        var listeners:Vector.<Listener> = nucleus.listeners;
        for (var i:int = listeners.length; --i >= 0;) {
            var listener:Listener = listeners[i];
            if (listener.cb == func && (!keyOrList || Utils.keysMatch(listener.keys, keyOrList))) {
                listeners.splice(i, 1);
            }
        }
        return this;
    }

    public function on(keyOrList:Object, func:Function):Atom {
        nucleus.listeners.unshift(new Listener(Utils.toArray(keyOrList), func, Number.POSITIVE_INFINITY));
        return this;
    }

    public function once(keyOrList:Object, func:Function):Atom {
        const keys:Array = Utils.toArray(keyOrList);
        const result:Result = nucleus.get(keys);
        if (Utils.isEmpty(result.missing)) {
            func.apply(null, result.values);
        } else {
            nucleus.listeners.unshift(new Listener(keys, func, 1, result.missing));
        }
        return this;
    }

    public function provide(key:String, func:Function):Atom {
        if (nucleus.needs[key]) {
            nucleus.provide(key, func);
        } else if (!nucleus.providers[key]) {
            nucleus.providers[key] = func;
        }
        return this;
    }

    public function set(keyOrMap:Object, value:Object = null):Atom {
        if (typeof(keyOrMap) == 'object') {
            for (var key:String in keyOrMap) {
                if (keyOrMap.hasOwnProperty(key)) {
                    nucleus.set(key, keyOrMap[key]);
                }
            }
        } else {
            nucleus.set(keyOrMap as String, value);
        }
        return this;
    }

    public function bind(keyOrList:Object, func:Function):Atom {
        return on(keyOrList, func);
    }

    public function unbind(keyOrList:Object, func:Function = null):Atom {
        return off(keyOrList, func);
    }
}
}

class Utils {
    public static function isEmpty(obj:Object):Boolean {
        for (var p:String in obj) {
            if (obj.hasOwnProperty(p)) {
                return false;
            }
        }
        return true;
    }

    public static function inArray(arr:Array, value:Object):Boolean {
        for each (var item:Object in arr) {
            if (item === value) {
                return true;
            }
        }
        return false;
    }

    public static function toArray(obj:Object):Array {
        return obj is Array ? obj as Array : [obj];
    }

    public static function keysMatch(keyOrListA:Object, keyOrListB:Object):Boolean {
        if (keyOrListA === keyOrListB) {
            return true;
        }
        var a:Array = toArray(keyOrListA).sort();
        var b:Array = toArray(keyOrListB).sort();
        return a + '' === b + '';
    }

    public static function preventMultiCall(callback:Function):Function {
        var ran:Boolean = false;
        return function (...args):void {
            if (!ran) {
                ran = true;
                callback.apply(null, args);
            }
        }
    }
}

class Listener {
    public var keys:Array;
    public var cb:Function;
    public var calls:Number;
    public var missing:Object;

    public function Listener(keys:Array, cb:Function, calls:Number=Number.POSITIVE_INFINITY, missing:Object=null) {
        this.keys = keys;
        this.cb = cb;
        this.calls = calls;
        this.missing = missing;
    }
}

class Result {
    public const values:Array = [];
    public const missing:Object = {};
}

class Nucleus {
    public var props:Object = {};
    public var needs:Object = {};
    public var providers:Object = {};
    public var listeners:Vector.<Listener> = new Vector.<Listener>();

    private var objStack:Array = [];

    public function destroy():void {
        props = null;
        needs = null;
        providers = null;
        listeners = null;
    }

    public function set(key:String, value:Object):void {
        var listenersCopy:Vector.<Listener> = listeners.concat();
        var oldValue:Object = props[key];
        var had:Boolean = props.hasOwnProperty(key);
        var isObj:Boolean = value && typeof(value) == 'object';

        props[key] = value;

        if (!had || oldValue !== value || (isObj && !Utils.inArray(objStack, value))) {
            if (isObj) {
                objStack.push(value);
            }

            for (var i:int = listenersCopy.length; --i >= 0; ) {
                var listener:Listener = listenersCopy[i];
                var keys:Array = listener.keys;
                var missing:Object = listener.missing;
                if (missing) {
                    if (missing.hasOwnProperty(key)) {
                        delete missing[key];
                        if (Utils.isEmpty(missing)) {
                            listener.cb.apply(null, get(keys).values);
                            listener.calls--;
                        }
                    }
                } else if (Utils.inArray(keys, key)) {
                    listener.cb.apply(null, get(keys).values);
                    listener.calls--;
                }
                if (!listener.calls) {
                    removeListener(listeners);
                }
            }

            delete needs[key];
            if (isObj) {
                objStack.pop();
            }
        }
    }

    public function get(keyOrList:Object, func:Function=null):Result {
        var isList:Boolean = keyOrList is Array;
        var keys:Array = isList ? keyOrList as Array : [keyOrList];
        var result:Result = new Result();

        for (var i:int = keys.length; --i >= 0;) {
            var key:String = keys[i];
            if (!props.hasOwnProperty(key)) {
                result.missing[key] = true;
            }
            result.values.unshift(props[key]);
        }
        return (func != null) ? func.apply(null, result.values) : result;
    }

    public function provide(key:String, provider:Function):void {
        provider(Utils.preventMultiCall(function (result:Object):void {
            set(key, result);
        }));
    }

    private static function removeListener(listeners:Vector.<Listener>):Vector.<Listener> {
        for (var i:int = listeners.length; --i >= 0; ) {
            if (!listeners[i].calls) {
                return listeners.splice(i, 1);
            }
        }
        return null;
    }
}

class Q {
    private var _queue:Array = [];
    private var _pending:Function = null;
    private var _args:Array = [];

    public function destroy():void {
        _queue = null;
        _pending = null;
        _args = null;
    }

    public function chain(...args):void {
        _queue = _queue.concat(args);
        if (_pending == null) {
            doNext.apply(null, _args);
        }
    }

    private function doNext(...args):void {
        _args = args;
        _pending = _queue.shift();
        if (_pending != null) {
            _pending.apply(null, [Utils.preventMultiCall(doNext)].concat(_args));
        }
    }
}
