import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:source_gen/source_gen.dart';
import 'package:data_classes/data_classes.dart';

Builder generateDataClass(BuilderOptions options) =>
    SharedPartBuilder([DataClassGenerator()], 'data_classes');

class DataClassGenerator extends GeneratorForAnnotation<GenerateDataClassFor> {
  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep _) {
    assert(element is ClassElement,
        'Only annotate classes with `@GenerateDataClassFor()`.');
    assert(
        element.name.startsWith('Mutable'),
        'The names of classes annotated with `@GenerateDataClassFor()` should '
        'start with `Mutable`, for example `MutableUser`. The immutable class '
        'will then get automatically generated for you by running '
        '`pub run build_runner build` (or '
        '`flutter pub run build_runner build` if you\'re using Flutter).');

    var e = element as ClassElement;
    var name = e.name.substring('Mutable'.length);
    var fields = <FieldElement>{};
    var getters = <FieldElement>{};

    for (var field in e.fields) {
      if (field.isFinal) {
        throw "`Mutable` classes shouldn't have final fields.";
      } else if (field.setter == null) {
        assert(field.getter != null);
        getters.add(field);
      } else if (field.getter == null) {
        assert(field.setter != null);
        throw "`Mutable` classes don't support setter-only fields";
      } else {
        fields.add(field);
      }
    }

    return '''
    /// This class is the immutable pendant of the [Mutable$name] class.
    @immutable
    class $name {
      ${fields.map((field) => 'final ${_fieldToTypeAndName(field)};').join()}

      /// Default constructor that creates a new [$name] with the given attributes.
      const $name({${fields.map((field) => '${_isNullable(field) ? '' : '@required'} this.${field.name},').join()}}) : ${fields.where((field) => !_isNullable(field)).map((field) => 'assert(${field.name} != null)').join(',')};

      /// Creates a [$name] from a [Mutable$name].
      $name.fromMutable(Mutable$name mutable) :
      ${fields.map((field) => '${field.name} = mutable.${field.name}').join(',')};

      /// Turns this [$name] into a [Mutable$name].
      Mutable$name toMutable() {
        return Mutable$name()
          ${fields.map((field) => '..${field.name} = ${field.name}').join()};
      }

      /// Checks if this [$name] is equal to the other one.
      bool operator ==(Object other) {
        return other is $name &&
            ${fields.map((field) => '${field.name} == other.${field.name}').join('&&')};
      }

      int get hashCode => hashList([${fields.map((field) => '${field.name},').join()}]);

      /// Copies this [$name] with some changed attributes.
      $name copy(void Function(Mutable$name mutable) changeAttributes) {
        assert(changeAttributes != null,
          "You called $name.copy, but didn't provide a function for changing "
          "the attributes.\\n"
          "If you just want an unchanged copy: You don't need one, just use "
          "the original.");
        var mutable = this.toMutable();
        changeAttributes(mutable);
        return  $name.fromMutable(mutable);
      }

      /// Converts this [$name] into a [String].
      String toString() {
        return '$name(\\n'
          ${fields.map((field) => "'  ${field.name}: \$${field.name}\\n'").join('\n')}
          ')';
      }
    }
    ''';
  }

  bool _isNullable(FieldElement field) =>
      field.metadata.any((annotation) => annotation.element.name == 'nullable');

  String _fieldToTypeAndName(FieldElement field) =>
      '${field.type.name} ${field.name}';
}
