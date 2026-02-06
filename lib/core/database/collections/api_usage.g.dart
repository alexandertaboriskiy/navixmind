// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_usage.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetApiUsageCollection on Isar {
  IsarCollection<ApiUsage> get apiUsages => this.collection();
}

const ApiUsageSchema = CollectionSchema(
  name: r'ApiUsage',
  id: 5623862975410959836,
  properties: {
    r'date': PropertySchema(
      id: 0,
      name: r'date',
      type: IsarType.dateTime,
    ),
    r'estimatedCostUsd': PropertySchema(
      id: 1,
      name: r'estimatedCostUsd',
      type: IsarType.double,
    ),
    r'inputTokens': PropertySchema(
      id: 2,
      name: r'inputTokens',
      type: IsarType.long,
    ),
    r'model': PropertySchema(
      id: 3,
      name: r'model',
      type: IsarType.string,
    ),
    r'outputTokens': PropertySchema(
      id: 4,
      name: r'outputTokens',
      type: IsarType.long,
    )
  },
  estimateSize: _apiUsageEstimateSize,
  serialize: _apiUsageSerialize,
  deserialize: _apiUsageDeserialize,
  deserializeProp: _apiUsageDeserializeProp,
  idName: r'id',
  indexes: {
    r'date': IndexSchema(
      id: -7552997827385218417,
      name: r'date',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'date',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _apiUsageGetId,
  getLinks: _apiUsageGetLinks,
  attach: _apiUsageAttach,
  version: '3.1.0+1',
);

int _apiUsageEstimateSize(
  ApiUsage object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.model.length * 3;
  return bytesCount;
}

void _apiUsageSerialize(
  ApiUsage object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.date);
  writer.writeDouble(offsets[1], object.estimatedCostUsd);
  writer.writeLong(offsets[2], object.inputTokens);
  writer.writeString(offsets[3], object.model);
  writer.writeLong(offsets[4], object.outputTokens);
}

ApiUsage _apiUsageDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ApiUsage();
  object.date = reader.readDateTime(offsets[0]);
  object.estimatedCostUsd = reader.readDouble(offsets[1]);
  object.id = id;
  object.inputTokens = reader.readLong(offsets[2]);
  object.model = reader.readString(offsets[3]);
  object.outputTokens = reader.readLong(offsets[4]);
  return object;
}

P _apiUsageDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _apiUsageGetId(ApiUsage object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _apiUsageGetLinks(ApiUsage object) {
  return [];
}

void _apiUsageAttach(IsarCollection<dynamic> col, Id id, ApiUsage object) {
  object.id = id;
}

extension ApiUsageQueryWhereSort on QueryBuilder<ApiUsage, ApiUsage, QWhere> {
  QueryBuilder<ApiUsage, ApiUsage, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhere> anyDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'date'),
      );
    });
  }
}

extension ApiUsageQueryWhere on QueryBuilder<ApiUsage, ApiUsage, QWhereClause> {
  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> dateEqualTo(
      DateTime date) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'date',
        value: [date],
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> dateNotEqualTo(
      DateTime date) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [date],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'date',
              lower: [],
              upper: [date],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> dateGreaterThan(
    DateTime date, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'date',
        lower: [date],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> dateLessThan(
    DateTime date, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'date',
        lower: [],
        upper: [date],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterWhereClause> dateBetween(
    DateTime lowerDate,
    DateTime upperDate, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'date',
        lower: [lowerDate],
        includeLower: includeLower,
        upper: [upperDate],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ApiUsageQueryFilter
    on QueryBuilder<ApiUsage, ApiUsage, QFilterCondition> {
  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> dateEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> dateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> dateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> dateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition>
      estimatedCostUsdEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'estimatedCostUsd',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition>
      estimatedCostUsdGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'estimatedCostUsd',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition>
      estimatedCostUsdLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'estimatedCostUsd',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition>
      estimatedCostUsdBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'estimatedCostUsd',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> inputTokensEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'inputTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition>
      inputTokensGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'inputTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> inputTokensLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'inputTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> inputTokensBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'inputTokens',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'model',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'model',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'model',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'model',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'model',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'model',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'model',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'model',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'model',
        value: '',
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> modelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'model',
        value: '',
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> outputTokensEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'outputTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition>
      outputTokensGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'outputTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> outputTokensLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'outputTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterFilterCondition> outputTokensBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'outputTokens',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ApiUsageQueryObject
    on QueryBuilder<ApiUsage, ApiUsage, QFilterCondition> {}

extension ApiUsageQueryLinks
    on QueryBuilder<ApiUsage, ApiUsage, QFilterCondition> {}

extension ApiUsageQuerySortBy on QueryBuilder<ApiUsage, ApiUsage, QSortBy> {
  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByEstimatedCostUsd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedCostUsd', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByEstimatedCostUsdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedCostUsd', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByInputTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputTokens', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByInputTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputTokens', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByOutputTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputTokens', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> sortByOutputTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputTokens', Sort.desc);
    });
  }
}

extension ApiUsageQuerySortThenBy
    on QueryBuilder<ApiUsage, ApiUsage, QSortThenBy> {
  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByEstimatedCostUsd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedCostUsd', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByEstimatedCostUsdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'estimatedCostUsd', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByInputTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputTokens', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByInputTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputTokens', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'model', Sort.desc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByOutputTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputTokens', Sort.asc);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QAfterSortBy> thenByOutputTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputTokens', Sort.desc);
    });
  }
}

extension ApiUsageQueryWhereDistinct
    on QueryBuilder<ApiUsage, ApiUsage, QDistinct> {
  QueryBuilder<ApiUsage, ApiUsage, QDistinct> distinctByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date');
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QDistinct> distinctByEstimatedCostUsd() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'estimatedCostUsd');
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QDistinct> distinctByInputTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inputTokens');
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QDistinct> distinctByModel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'model', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ApiUsage, ApiUsage, QDistinct> distinctByOutputTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'outputTokens');
    });
  }
}

extension ApiUsageQueryProperty
    on QueryBuilder<ApiUsage, ApiUsage, QQueryProperty> {
  QueryBuilder<ApiUsage, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ApiUsage, DateTime, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<ApiUsage, double, QQueryOperations> estimatedCostUsdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'estimatedCostUsd');
    });
  }

  QueryBuilder<ApiUsage, int, QQueryOperations> inputTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inputTokens');
    });
  }

  QueryBuilder<ApiUsage, String, QQueryOperations> modelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'model');
    });
  }

  QueryBuilder<ApiUsage, int, QQueryOperations> outputTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputTokens');
    });
  }
}
