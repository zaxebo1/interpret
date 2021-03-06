package interpret;

enum Token {

    TPackage(data:TPackage);

    TImport(data:TImport);
    
    TUsing(data:TUsing);
    
    TModifier(data:TModifier);
    
    TMeta(data:TMeta);
    
    TComment(data:TComment);
    
    TField(data:TField);

    TType(data:TType);

} //Token

enum RuntimeItem {

    ExtensionItem(item:RuntimeItem, ?extendedType:String);

    ClassFieldItem(rawItem:Dynamic, moduleId:Int, name:String, isStatic:Bool, type:String, ?argTypes:Array<String>);

    ClassItem(rawItem:Dynamic, moduleId:Int, name:String);

    AbstractItem(rawItem:Dynamic, moduleId:Int, name:String, runtimeType:String);

    AbstractFieldItem(rawItem:Dynamic, moduleId:Int, name:String, isStatic:Bool, type:String, ?argTypes:Array<String>);

    EnumItem(rawItem:Dynamic, moduleId:Int, name:String);

    EnumFieldItem(rawItem:Dynamic, name:String, numArgs:Int);

    PackageItem(pack:DynamicPackage);

    SuperClassItem(item:RuntimeItem);

} //RuntimeItem

@:structInit
class TPackage {

    public var pos:Int;

    public var path:String;

} //TPackage

@:structInit
class TImport {

    public var pos:Int;

    public var path:String;

    public var name:String;

    @:optional public var alias:String = null;

} //TImport

@:structInit
class TUsing {

    public var pos:Int;

    public var path:String;

} //TUsing

@:structInit
class TModifier {

    public var pos:Int;

    public var name:String;

} //TModifier

@:structInit
class TMeta {

    public var pos:Int;

    public var name:String;

    @:optional public var args:Array<String> = null;

} //TMeta

@:structInit
class TComment {

    public var pos:Int;

    public var content:String;

    public var multiline:Bool;

} //TComment

@:structInit
class TField {

    public var name:String;

    public var pos:Int;

    public var kind:TFieldKind;

    public var type:String;

    @:optional public var args:Array<TArg> = null;

    @:optional public var get:String = null;

    @:optional public var set:String = null;

    @:optional public var expr:String = null;

    public function isEqualToField(field:TField) {

        if (field == null) return false;
        if (field.name != name) return false;
        if (field.expr != expr) return false;
        if (field.kind != kind) return false;
        if (field.get != get) return false;
        if (field.set != set) return false;
        if (field.type != type) return false;
        if (field.args == null && args != null) return false;
        if (field.args != null && args == null) return false;
        if (field.args != null && args != null) {
            if (field.args.length != args.length) return false;
            for (i in 0...field.args.length) {
                if (!field.args[i].isEqualToArg(args[i])) return false;
            }
        }
        return true;

    } //isEqualToField

} //TField

enum TFieldKind {

    VAR;

    METHOD;

} //TFieldKind

@:structInit
class TArg {

    public var pos:Int;

    @:optional public var name:String = null;

    public var type:String;

    @:optional public var opt:Bool = false;

    @:optional public var expr:String;

    public function isEqualToArg(arg:TArg) {

        if (arg == null) return false;
        if (arg.name != name) return false;
        if (arg.expr != expr) return false;
        if (arg.opt != opt) return false;
        if (arg.type != type) return false;
        return true;

    } //isEqualToArg

} //TArg

@:structInit
class TType {

    public var pos:Int;

    public var name:String;

    public var kind:TTypeKind;

    @:optional public var type:String;

    @:optional public var interfaces:Array<TParent>;

    @:optional public var parent:TParent;

} //TType

@:structInit
class TParent {

    public var name:String;

    public var kind:TParentKind;

} //TParent

enum TTypeKind {

    CLASS;

    ENUM;

    TYPEDEF;

    ABSTRACT;

} //TTypeKind

enum TParentKind {

    SUPERCLASS;

    INTERFACE;

} //TTypeKind

class ModuleItemKind {

    public inline static var CLASS = 0;

    public inline static var CLASS_FUNC = 1;

    public inline static var CLASS_VAR = 2;

    public inline static var ENUM = 3;

    public inline static var ENUM_FIELD = 4;

    public inline static var ABSTRACT = 5;

    public inline static var ABSTRACT_FUNC = 6;

    public inline static var ABSTRACT_VAR = 7;

} //ModuleItemKind
