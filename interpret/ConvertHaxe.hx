package interpret;

import interpret.Types;

using StringTools;

class ConvertHaxe {

    var haxe(default,null):String;

    var cleanedHaxe(default,null):String;

    public var tokens(default,null):Array<Token>;

    public var transformToken:Token->Token = null;

    public function new(haxe:String) {

        this.haxe = haxe.replace("\r", '');

    } //new

/// Convert

    var i:Int = 0;

    var len:Int = 0;

    var c:String = '';

    var cc:String = '';

    var after:String = '';

    var cleanedC:String = '';

    var cleanedCC:String = '';

    var cleanedAfter:String = '';

    var word:String = '';

    var openBraces:Int = 0;

    var openParens:Int = 0;

    var openBrackets:Int = 0;

    var inClassBraces:Int = -1;

    var inEnumBraces:Int = -1;

    public function convert():Void {

        // Generate cleaned haxe code
        cleanedHaxe = codeWithoutComments(haxe).replace("\n", ' ');

        // Reset data
        //
        tokens = [];
        inClassBraces = -1;
        inEnumBraces = -1;

        i = 0;
        len = haxe.length;
        c = '';
        cc = '';
        after = '';
        cleanedC = '';
        cleanedCC = '';
        cleanedAfter = '';
        word = '';

        openBraces = 0;
        openParens = 0;
        openBrackets = 0;

        // Iterate over each character and generate tokens
        //
        while (i < len) {
            updateCAndCC();

            if (cc == '//') {
                consumeSingleLineComment();
            }
            else if (cc == '/*') {
                consumeMultiLineComment();
            }
            else if (c == '@') {
                consumeMeta();
            }
            else if (c == '{') {
                openBraces++;
                i++;
            }
            else if (c == '}') {
                openBraces--;
                i++;
                if (inClassBraces != -1 && inClassBraces > openBraces) {
                    inClassBraces = -1;
                }
                else if (inEnumBraces != -1 && inEnumBraces > openBraces) {
                    inEnumBraces = -1;
                }
            }
            else {
                updateCleanedAfter();
                updateAfter();
                updateWord();
                
                if (MODIFIERS.exists(word)) {
                    addToken(TModifier({
                        pos: i,
                        name: word
                    }));
                    i += word.length;
                }
                else if (word == 'import') {
                    consumeImport();
                }
                else if (word == 'using') {
                    consumeUsing();
                }
                else if (word == 'package') {
                    consumePackage();
                }
                else if (inClassBraces != -1) {
                    if (word == 'var' || word == 'final') {
                        consumeVar();
                    }
                    else if (word == 'function') {
                        consumeMethod();
                    }
                    else {
                        i++;
                    }
                }
                else if (inEnumBraces != -1) {
                    /*if (word == 'var' || word == 'final') {
                        consumeVar();
                    }
                    else if (word == 'function') {
                        consumeMethod();
                    }
                    else {*/
                        i++;
                    //}
                }
                else {
                    if (word == 'class') {
                        consumeClassDecl();
                    }
                    else if (word == 'enum') {
                        consumeEnumDecl();
                    }
                    else if (word == 'abstract') {
                        consumeAbstract();
                    }
                    else if (word == 'typedef') {
                        consumeTypedef();
                    }
                    else {
                        i++;
                    }
                }
            }

        }

    } //convert

/// Add token hook

    inline function addToken(token:Token):Void {

        if (transformToken != null) {
            token = transformToken(token);
        }

        tokens.push(token);

    } //addToken

/// Conversion helpers

    inline function updateC() {

        c = haxe.charAt(i);

    } //updateC

    inline function updateCC() {

        cc = haxe.substr(i, 2);

    } //updateCC

    inline function updateCAndCC() {

        updateC();
        updateCC();

    } //updateCAndCC

    inline function updateAfter() {

        after = haxe.substring(i);

    } //updateAfter

    inline function updateCleanedC() {

        cleanedC = cleanedHaxe.charAt(i);

    } //updateCleanedC

    inline function updateCleanedCC() {

        cleanedCC = cleanedHaxe.substr(i, 2);

    } //updateCleanedCC

    inline function updateCleanedCAndCC() {

        updateCleanedC();
        updateCleanedCC();

    } //updateCleanedCAndCC

    inline function updateCleanedAfter() {

        cleanedAfter = cleanedHaxe.substring(i);

    } //updateCleanedAfter

    inline function updateWord() {

        var result:String = '';

        if (i > 0 && RE_SEP_WORD.match(haxe.charAt(i-1) + after)) {
            result = RE_SEP_WORD.matched(1);
        }
        else if (i == 0 && RE_WORD.match(after)) {
            result = RE_WORD.matched(0);
        }
        
        word = result;

    } //updateWord

    function consumeExpression(until:String, ?expr:StringBuf):{stop:String, expr:String} {

        var untilMap = UNTIL_MAPS[until];
        if (untilMap == null) fail('Invalid expression until: $until', i, haxe);

        var _expr = new StringBuf();

        var openParensStart = openParens;
        var openBracesStart = openBraces;
        var openBracketsStart = openBrackets;
        var stop:String = null;

        var stopAtParenClose = untilMap.exists(')');
        var stopAtBraceClose = untilMap.exists('}');
        var stopAtBracketClose = untilMap.exists(']');
        var stopAtComa = untilMap.exists(',');
        var stopAtSemicolon = untilMap.exists(';');

        while (i < len) {
            updateCAndCC();

            if (cc == '//') {
                consumeSingleLineComment(_expr);
            }
            else if (cc == '/*') {
                consumeMultiLineComment(_expr);
            }
            else if (c == '@') {
                consumeMeta(_expr);
            }
            else if (c == '\'') {
                consumeSingleQuotedString(_expr);
            }
            else if (c == '"') {
                consumeDoubleQuotedString(_expr);
            }
            else if (c == '(') {
                openParens++;
                _expr.add('(');
                i++;
            }
            else if (c == '{') {
                openBraces++;
                _expr.add('{');
                i++;
            }
            else if (c == '[') {
                openBrackets++;
                _expr.add('[');
                i++;
            }
            else if (c == ')') {
                if (stopAtParenClose && openParens == openParensStart && openBraces == openBracesStart && openBrackets == openBracketsStart) {
                    stop = c;
                    break;
                }
                openParens--;
                _expr.add(')');
                i++;
            }
            else if (c == '}') {
                if (stopAtBraceClose && openParens == openParensStart && openBraces == openBracesStart && openBrackets == openBracketsStart) {
                    stop = c;
                    break;
                }
                openBraces--;
                _expr.add('}');
                i++;
            }
            else if (c == ']') {
                if (stopAtBracketClose && openParens == openParensStart && openBraces == openBracesStart && openBrackets == openBracketsStart) {
                    stop = c;
                    break;
                }
                openBrackets--;
                _expr.add(']');
                i++;
            }
            else if (cc == '->') {
                i += 2; // TODO
            }
            else if (c == ',') {
                if (stopAtComa && openParens == openParensStart && openBraces == openBracesStart && openBrackets == openBracketsStart) {
                    stop = c;
                    break;
                }
                _expr.add(',');
                i++;
            }
            else if (c == ';') {
                if (stopAtSemicolon && openParens == openParensStart && openBraces == openBracesStart && openBrackets == openBracketsStart) {
                    stop = c;
                    break;
                }
                _expr.add(';');
                i++;
            }
            else {
                updateCleanedAfter();
                updateAfter();
                updateWord();

                if (MODIFIERS.exists(word)) {
                    i += word.length;
                }
                else if (word == 'super') {
                    i += word.length;
                    if (RE_SUPER_CONSTRUCTOR_CALL.match(cleanedAfter)) {
                        _expr.add('__super_new');
                    }
                    else {
                        _expr.add('super');
                    }
                }
                else if (word == 'var' || word == 'final') {
                    consumeVar(_expr);
                }
                else if (word == 'cast') {
                    consumeCast(_expr);
                }
                else if (word == 'new') {
                    consumeNew(_expr);
                }
                else if (word == 'function') {
                    consumeFunction(_expr);
                }
                else {
                    _expr.add(c);
                    i++;
                }
            }
        }

        var exprStr = _expr.toString();

        if (expr != null) {
            expr.add(exprStr);
        }

        return {
            stop: stop,
            expr: exprStr
        };

    } //consumeExpression

    function consumeClassDecl() {

        // We assume cleanedAfter is up to date

        if (!RE_CLASS_DECL.match(cleanedAfter)) {
            fail('Invalid class', i, haxe);
        }

        var interfaces:Array<TParent> = [];
        var parent:TParent = null;
        var parentsCode = RE_CLASS_DECL.matched(2);
        if (parentsCode != null) {
            parentsCode = parentsCode.trim();
            while (RE_CLASS_PARENT.match(parentsCode)) {
                var parentName = cleanType(RE_CLASS_PARENT.matched(2));
                var parentKeyword = RE_CLASS_PARENT.matched(1);
                if (parentKeyword == 'implements') {
                    interfaces.push({
                        name: parentName,
                        kind: INTERFACE
                    });
                } else {
                    parent = {
                        name: parentName,
                        kind: SUPERCLASS
                    };
                }
                parentsCode = parentsCode.substring(RE_CLASS_PARENT.matched(0).length);
            }
        }

        i += RE_CLASS_DECL.matched(0).length;
        openBraces++;
        inClassBraces = openBraces;

        addToken(TType({
            pos: i,
            kind: CLASS,
            name: RE_CLASS_DECL.matched(1),
            interfaces: interfaces,
            parent: parent
        }));

    } //consumeClassDecl

    function consumeEnumDecl() {

        // We assume cleanedAfter is up to date

        if (!RE_ENUM_DECL.match(cleanedAfter)) {
            fail('Invalid enum', i, haxe);
        }

        i += RE_ENUM_DECL.matched(0).length;
        openBraces++;
        inEnumBraces = openBraces;

        addToken(TType({
            pos: i,
            kind: ENUM,
            name: RE_ENUM_DECL.matched(2)
        }));

    } //consumeClassDecl

    function consumeAbstract() {

        // We assume cleanedAfter is up to date

        if (!RE_ABSTRACT_DECL.match(cleanedAfter)) {
            fail('Invalid abstract', i, haxe);
        }

        i += RE_ABSTRACT_DECL.matched(0).length;
        openBraces++;

        var type = RE_ABSTRACT_DECL.matched(2);
        if (type != null) type = cleanType(type);

        addToken(TType({
            pos: i,
            kind: ABSTRACT,
            name: RE_ABSTRACT_DECL.matched(1),
            type: type
        }));

        // Consume abstract content (we don't do anything with it)
        openBraces++;
        consumeExpression('}');
        i++;
        openBraces--;

    } //consumeAbstract

    function consumeTypedef() {

        // We assume cleanedAfter is up to date

        if (!RE_TYPEDEF_DECL.match(cleanedAfter)) {
            fail('Invalid typedef', i, haxe);
        }

        i += RE_TYPEDEF_DECL.matched(0).length;
        openBraces++;

        var type = RE_TYPEDEF_DECL.matched(3) != '' ? RE_TYPEDEF_DECL.matched(3) : null;
        if (type != null) type = cleanType(type);

        addToken(TType({
            pos: i,
            kind: TYPEDEF,
            name: RE_TYPEDEF_DECL.matched(1),
            type: type
        }));

        // Consume typedef content (we don't do anything with it)
        if (RE_TYPEDEF_DECL.matched(2) == '{') {
            openBraces++;
            consumeExpression('}');
            i++;
            openBraces--;
        }

    } //consumeTypedef

    function consumeImport() {

        // We assume cleanedAfter is up to date

        if (!RE_IMPORT.match(cleanedAfter)) {
            fail('Invalid import', i, haxe);
        }

        var path = RE_IMPORT.matched(1);
        var alias = RE_IMPORT.matched(2);

        var parts = path.split('.');

        var imp:TImport = {
            pos: i,
            path: path,
            name: parts[parts.length-1],
            alias: alias != null && alias != '' ? alias : null
        };
        addToken(TImport(imp));

        i += RE_IMPORT.matched(0).length;

    } //consumeImport

    function consumeUsing() {

        // We assume cleanedAfter is up to date

        if (!RE_USING.match(cleanedAfter)) {
            fail('Invalid using', i, haxe);
        }

        var path = RE_USING.matched(1);

        var use:TUsing = {
            pos: i,
            path: path
        };
        addToken(TUsing(use));

        i += RE_USING.matched(0).length;

    } //consumeUsing

    function consumeVar(?expr:StringBuf) {

        // We assume cleanedAfter is up to date

        if (!RE_VAR.match(cleanedAfter)) {
            fail('Invalid var', i, haxe);
        }

        //var isFinal = RE_VAR.matched(1) == 'final';
        var name = RE_VAR.matched(2);
        var get = RE_VAR.matched(3);
        var set = RE_VAR.matched(4);
        var type = RE_VAR.matched(5);
        var stop = RE_VAR.matched(6);

        if (type != null) type = cleanType(type);

        var field:TField = {
            pos: i,
            kind: VAR,
            name: name,
            type: type
        };

        if (get != null && get != '') {
            field.get = get;
        }

        if (set != null && set != '') {
            field.set = set;
        }

        i += RE_VAR.matched(0).length;
        if (stop == '=') {
            field.expr = consumeExpression(';').expr.trim();
            i++;
        }

        if (expr != null) {
            expr.add('var $name');
            if (field.expr != null) {
                expr.add(' = ' + field.expr);
            }
            expr.add(';');
        } else {
            addToken(TField(field));
        }

    } //consumeVar

    function consumeCast(?expr:StringBuf) {

        // We assume cleanedAfter is up to date
        
        if (!RE_CAST.match(cleanedAfter)) {
            fail('Invalid cast', i, haxe);
        }

        var hasParen = RE_CAST.matched(1) == '(';
        i += RE_CAST.matched(0).length;

        if (hasParen) {
            var result;
            var gotFirstExpr = false;
            do {
                result = consumeExpression(',)');
                if (!gotFirstExpr) {
                    gotFirstExpr = true;
                    if (expr != null) expr.add('(' + result.expr + ')');
                }
                i++;
            }
            while (result.stop == ',');
        }

    } //consumeCast

    function consumeNew(?expr:StringBuf) {

        // We assume cleanedAfter is up to date
        
        if (!RE_NEW.match(cleanedAfter)) {
            fail('Invalid new', i, haxe);
        }

        if (expr != null) {
            expr.add('new ');
            expr.add(RE_NEW.matched(1));
            expr.add('(');
        }

        i += RE_NEW.matched(0).length;

        var result = consumeExpression(')');
        if (expr != null) {
            expr.add(result.expr);
            expr.add(')');
        }

        i++;

    } //consumeNew

    function consumeFunction(?expr:StringBuf) {

        // We assume cleanedAfter is up to date

        inline function add(str:String) {
            if (expr != null) expr.add(str);
        }

        if (!RE_FUNCTION.match(cleanedAfter)) {
            fail('Invalid function', i, haxe);
        }

        if (expr != null) {
            expr.add(RE_FUNCTION.matched(0));
        }
        i += RE_FUNCTION.matched(0).length;
        openParens++;
        
        // Parse args
        var defaults:Array<Array<String>> = null;
        var result;
        do {
            result = consumeExpression(',)');
            if (result.expr != '') {
                var arg = parseNamedArg(result.expr);
                if (arg.opt) {
                    add('?');
                }
                add(arg.name);
                if (arg.expr != null) {
                    if (defaults == null) defaults = [];
                    defaults.push([arg.name, arg.expr]);
                }
            }
            add(result.stop);
            i++;
        }
        while (result.stop == ',');

        openParens--;

        // Nothing else special to do if there are no default values
        if (defaults == null) return;

        // Insert default assigns function
        inline function addDefaultAssigns() {
            for (item in defaults) {
                var name = item[0];
                var value = item[1];
                add(' if ($name == null) $name = $value;');
            }
        }

        // Parse return type and body
        updateCleanedAfter();
        if (RE_FUNC_BLOCK_START.match(cleanedAfter)) {

            i += RE_FUNC_BLOCK_START.matched(0).length;

            // Block with braces
            openBraces++;
            add('{');
            addDefaultAssigns();
            add(consumeExpression('}').expr);
            add('}');
            i++;
            openBraces--;
        }
        else {
            if (RE_FUNC_RET_TYPE.match(cleanedAfter)) {
                i += RE_FUNC_RET_TYPE.matched(0).length;
            }

            // Body without braces
            add('{');
            addDefaultAssigns();
            add(consumeExpression(';').expr.ltrim() + ';');
            add('}');
            i++;
        }

    } //consumeFunction

    function consumeMethod() {

        // We assume cleanedAfter is up to date

        if (!RE_METHOD.match(cleanedAfter)) {
            fail('Invalid method', i, haxe);
        }

        var name = RE_METHOD.matched(1);
        var pos = i;
        var ret:String = null;

        i += RE_METHOD.matched(0).length;
        openParens++;

        // Parse args
        var args = [];
        var result;
        do {
            result = consumeExpression(',)');
            if (result.expr != '') {
                var arg = parseNamedArg(result.expr);
                args.push(arg);
            }
            i++;
        }
        while (result.stop == ',');

        openParens--;

        // Parse return type and body
        updateCleanedAfter();
        var body:String;
        if (RE_FUNC_BLOCK_START.match(cleanedAfter)) {

            ret = RE_FUNC_BLOCK_START.matched(2);
            i += RE_FUNC_BLOCK_START.matched(0).length;

            // Block with braces
            openBraces++;
            body = '{' + consumeExpression('}').expr + '}';
            i++;
            openBraces--;
        }
        else {
            if (RE_FUNC_RET_TYPE.match(cleanedAfter)) {
                ret = RE_FUNC_RET_TYPE.matched(2);
                i += RE_FUNC_RET_TYPE.matched(0).length;
            }

            // Body without braces
            body = consumeExpression(';').expr.ltrim() + ';';
            i++;
        }

        if (ret != null) ret = cleanType(ret);

        var field:TField = {
            pos: pos,
            kind: METHOD,
            name: name,
            type: ret,
            args: args,
            expr: body
        };

        addToken(TField(field));

    } //consumeMethod

    function consumeSingleLineComment(?expr:StringBuf) {

        var content = new StringBuf();
        var comment:TComment = {
            pos: i,
            multiline: false,
            content: null
        };

        i += 2;

        while (i < len) {
            updateC();
            if (c == "\n") {
                i++;
                break;
            }
            else {
                content.add(c);
                i++;
            }
        }

        if (expr != null) {
            // Nothing to add
        } else {
            comment.content = cleanComment(content.toString());
            addToken(TComment(comment));
        }

    } //consumeSingleLineComment

    function consumeMultiLineComment(?expr:StringBuf) {

        var content = new StringBuf();
        var comment:TComment = {
            pos: i,
            multiline: true,
            content: null
        };

        i += 2;

        while (i < len) {
            updateCAndCC();
            if (cc == '*/') {
                i += 2;
                break;
            }
            else {
                i++;
                content.add(c);
            }
        }

        if (expr != null) {
            // Nothing to add
        } else {
            comment.content = cleanComment(content.toString());
            addToken(TComment(comment));
        }

    } //consumeMultiLineComment

    function consumeSingleQuotedString(?expr:StringBuf) {

        inline function add(str:String) {
            if (expr != null) expr.add(str);
        }

        i++;
        add('\'');

        while (i < len) {
            updateCAndCC();

            if (c == '\\') {
                i += 2;
                add(cc);
            }
            else if (cc == "$$") {
                i += 2;
                add(cc);
            }
            else if (cc == "${") {
                i += 2;
                openBraces++;
                add('\'+(');
                consumeExpression('}', expr);
                openBraces--;
                add(')+\'');
                i++;
            }
            else if (c == "$") {
                i++;
                add('\'+');
                consumeWord(expr);
                add('+\'');
            }
            else if (c == '\'') {
                i++;
                add('\'');
                break;
            }
            else {
                i++;
                add(c);
            }
        }

    } //consumeSingleQuotedString

    function consumeDoubleQuotedString(?expr:StringBuf) {

        inline function add(str:String) {
            if (expr != null) expr.add(str);
        }

        i++;
        add('"');

        while (i < len) {
            updateCAndCC();

            if (c == '\\') {
                i += 2;
                add(cc);
            }
            else if (c == '"') {
                i++;
                add('"');
                break;
            }
            else {
                i++;
                add(c);
            }
        }

    } //consumeDoubleQuotedString

    function consumeWord(?expr:StringBuf) {

        updateAfter();

        if (!RE_WORD.match(after)) {
            fail('Invalid token', i, haxe);
        }

        if (expr != null) expr.add(RE_WORD.matched(0));
        i += RE_WORD.matched(0).length;

    } //consumeWord

    function consumeMeta(?expr:StringBuf) {

        updateCleanedAfter();

        if (!RE_META.match(cleanedAfter)) {
            fail('Invalid meta', i, haxe);
        }

        var name = (RE_META.matched(1) != null ? RE_META.matched(1) : '') + RE_META.matched(2);
        var spaces = RE_META.matched(3);
        var paren = RE_META.matched(4);

        var meta:TMeta = {
            pos: i,
            name: (RE_META.matched(1) != null ? RE_META.matched(1) : '') + RE_META.matched(2),
            args: null
        };

        i += RE_META.matched(0).length;

        if (paren == '(') {
            openParens++;
            meta.args = [];
            var result;
            do {
                result = consumeExpression(',)');
                if (result.expr != '') {
                    meta.args.push(result.expr);
                }
                i++;
            }
            while (result.stop == ',');
            openParens--;
        }

        if (expr != null) {
            // Nothing to add
        } else {
            addToken(TMeta(meta));
        }

    } //consumeMeta

    function consumePackage() {

        var pos = i;
        i += word.length;
        var pack = '';
        var c = cleanedHaxe.charAt(i);
        while (c != ';') {
            pack += c;
            i++;
            c = cleanedHaxe.charAt(i);
        }
        i++;
        
        if (pack.trim() != '') {
            addToken(TPackage({
                pos: pos,
                path: pack.trim()
            }));
        }

    } //consumePackage

    function parseNamedArg(rawArg:String) {

        rawArg = rawArg.trim();

        if (!RE_NAMED_ARG.match(rawArg)) {
            fail('Invalid argument', i, haxe);
        }

        var type = RE_NAMED_ARG.matched(3);
        if (type != null) type = cleanType(type);

        var arg:TArg = {
            pos: i,
            name: RE_NAMED_ARG.matched(2),
            type: type,
            expr: RE_NAMED_ARG.matched(4),
            opt: RE_NAMED_ARG.matched(1) == '?' || (RE_NAMED_ARG.matched(4) != null && RE_NAMED_ARG.matched(4) != '')
        };

        return arg;

    } //parseArg

/// Helpers

    static function fail(error:Dynamic, pos:Int, code:String) {

        // TODO proper error formatting

        trace(error + ' (' + code.substr(pos, 100) + ')');

        throw '' + error;

    } //fail

    static function cleanType(rawType:String):String {

        var cleanedType = RE_ANY_SPACE.replace(rawType, '');

        // TODO handle function type

        if (cleanedType.startsWith('Null<')) {
            cleanedType = cleanedType.substring(5, cleanedType.length-1);
        }

        if (cleanedType.startsWith('Class<')) {
            var classType = cleanedType.substring(6, cleanedType.length-1);
            cleanedType = 'Class<' + cleanType(classType) + '>';
        }
        else if (cleanedType.startsWith('Enum<')) {
            var classType = cleanedType.substring(5, cleanedType.length-1);
            cleanedType = 'Enum<' + cleanType(classType) + '>';
        }
        else {
            // Remove type params
            if (RE_TYPE_WITH_PARAM.match(cleanedType)) {
                cleanedType = RE_TYPE_WITH_PARAM.matched(1);
            }
        }

        return cleanedType;

    } //cleanType

    static function cleanComment(comment:String):String {

        var lines = [];

        // Remove noise (asterisks etc...)
        for (line in comment.split("\n")) {
            var lineLen = line.length;
            line = RE_BEFORE_COMMENT_LINE.replace(line, '');
            while (line.length < lineLen) {
                line = ' ' + line;
            }
            line = RE_AFTER_COMMENT_LINE.replace(line, '');
            lines.push(line);
        }

        if (lines.length == 0) return '';

        // Remove indent common with all lines
        var commonIndent = 99999;
        for (line in lines) {
            if (line.trim() != '') {
                commonIndent = Std.int(Math.min(commonIndent, line.length - line.ltrim().length));
            }
        }
        if (commonIndent > 0) {
            for (i in 0...lines.length) {
                lines[i] = lines[i].substring(commonIndent);
            }
        }

        return lines.join("\n").trim();

    } //cleanComment

    static function codeWithoutComments(code:String) {

        var i = 0;
        var c = '';
        var cc = '';
        var after = '';
        var len = code.length;
        var inSingleLineComment = false;
        var inMultiLineComment = false;
        var result = new StringBuf();

        while (i < len) {

            c = code.charAt(i);
            cc = i + 1 < len ? (c + code.charAt(i + 1)) : c;

            if (inSingleLineComment) {
                if (c == "\n") {
                    inSingleLineComment = false;
                }
                result.add(' ');
                i++;
            }
            else if (inMultiLineComment) {
                if (cc == '*/') {
                    inMultiLineComment = false;
                    result.add('  ');
                    i += 2;
                } else {
                    result.add(' ');
                    i++;
                }
            }
            else if (cc == '//') {
                inSingleLineComment = true;
                result.add('  ');
                i += 2;
            }
            else if (cc == '/*') {
                inMultiLineComment = true;
                result.add('  ');
                i += 2;
            }
            else if (c == '"' || c == '\'') {
                after = code.substring(i);
                if (!RE_STRING.match(after)) {
                    fail('Invalid string', i, code);
                }
                result.add(RE_STRING.matched(0));
                i += RE_STRING.matched(0).length;
            }
            else {
                result.add(c);
                i++;
            }
        }

        return result.toString();

    } //codeWithEmptyCommentsAndStrings

/// Maps

    static var UNTIL_MAPS = [
        ',)' => [',' => true, ')' => true],
        ')' => [')' => true],
        '}' => ['}' => true],
        ';' => [';' => true],
        '>' => ['>' => true]
    ];

    static var MODIFIERS = [
        'inline' => true,
        'static' => true,
        'public' => true,
        'protected' => true,
        'dynamic' => true,
        'override' => true,
        'private' => true,
        'untyped' => true
    ];

/// Regular expressions

    static var RE_BEFORE_COMMENT_LINE = ~/^[\s\*]*(\/\/)?\s*/g;

    static var RE_AFTER_COMMENT_LINE = ~/[\s\*]*$/g;

    static var RE_META = ~/^@(:)?([a-zA-Z_][a-zA-Z_0-9]*)(\s*)(\()?/g;
    
    static var RE_WORD = ~/^[a-zA-Z0-9_]+/;

    static var RE_SEP_WORD = ~/^[^a-zA-Z0-9_]([a-zA-Z0-9_]+)/;

    static var RE_IMPORT = ~/^import\s+([^;\s]+)\s*(?:(?:as|in)\s*([^;\s]+)\s*)?;/;

    static var RE_USING = ~/^using\s+([^;\s]+)\s*;/;

    static var RE_VAR = ~/^(var|final)\s+([a-zA-Z_][a-zA-Z_0-9]*)(?:\s*\(\s*(get|null|never|default)\s*,\s*(set|null|never|default)\s*\))?(?:\s*:\s*([^=;]+))?(?:\s*(=|;))?/;

    static var RE_METHOD = ~/^function\s+([a-zA-Z_][a-zA-Z_0-9]*)(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?\s*\(/;

    static var RE_FUNCTION = ~/^function(?:\s+([a-zA-Z_][a-zA-Z_0-9]*)(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?)?\s*\(/;

    static var RE_STRING = ~/^(?:"(?:[^"\\]*(?:\\.[^"\\]*)*)"|'(?:[^'\\]*(?:\\.[^'\\]*)*)')/;

    static var RE_NAMED_ARG = ~/^(?:(\?)\s*)?([a-zA-Z_][a-zA-Z_0-9]*)(?:\s*:\s*([a-zA-Z0-9,<>_:?()\s-]+))?(?:\s*=\s*(.*))?/;

    static var RE_FUNC_BLOCK_START = ~/^(?:(\s*:\s*)([a-zA-Z0-9_]+(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?))?\s*{/;

    static var RE_FUNC_RET_TYPE = ~/^(\s*:\s*)([a-zA-Z0-9_]+(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?)/;

    static var RE_CAST = ~/^cast(?:\s*(\())?/;

    static var RE_NEW = ~/^new\s+((?:[a-zA-Z_][a-zA-Z_0-9]*\.)*[a-zA-Z_][a-zA-Z_0-9]*)(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?\s*\(/;

    static var RE_CLASS_DECL = ~/^class\s+([a-zA-Z_][a-zA-Z_0-9]*)(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?([^{]*)\s*{/;

    static var RE_ENUM_DECL = ~/^enum(\s+abstract)?\s+([a-zA-Z_][a-zA-Z_0-9]*)([^{]*)\s*{/;

    static var RE_ABSTRACT_DECL = ~/^abstract\s+([a-zA-Z_][a-zA-Z_0-9]*(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?)\s*(?:\(\s*((?:[a-zA-Z0-9,<>_:?\s-]+|\([a-zA-Z0-9,<>_:?\s-]+\))+)\s*\))([^{]*)\s*{/;

    static var RE_TYPEDEF_DECL = ~/^typedef\s+([a-zA-Z_][a-zA-Z_0-9]*(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?)\s*=\s*({|([^;]*);)/;

    static var RE_ANY_SPACE = ~/\s+/gm;

    static var RE_TYPE_WITH_PARAM = ~/^([a-zA-Z_][a-zA-Z_0-9]*)\s*<([a-zA-Z0-9,<>_:?()\s-]+)>/;

    static var RE_CLASS_PARENT = ~/^\s*(implements|extends)\s+((?:[a-zA-Z_][a-zA-Z_0-9\.]*)(?:\s*<[a-zA-Z0-9,<>_:?()\s-]+>)?)/;

    static var RE_SUPER_CONSTRUCTOR_CALL = ~/^super\s*\(/;

} //HaxeToHscript
