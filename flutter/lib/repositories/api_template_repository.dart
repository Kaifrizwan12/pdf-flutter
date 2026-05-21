import '../models/element_type.dart';
import '../models/template_model.dart';
import '../services/api_service.dart';
import 'template_repository.dart';

class ApiTemplateRepository implements TemplateRepository {
  final ApiService _api;

  ApiTemplateRepository({required ApiService api}) : _api = api;

  @override
  Future<TemplatePageResult> fetchTemplates(
    String companyId, {
    TemplateType? type,
    Object? cursor,
  }) async {
    final q = type != null ? '?type=${type.jsonKey}' : '';
    final json = await _api.get('/api/templates$q');
    final items = (json['templates'] as List<dynamic>? ?? [])
        .map((e) => TemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return TemplatePageResult(items: items);
  }

  @override
  Future<TemplateModel?> fetchTemplate(
      String companyId, String templateId) async {
    try {
      final json = await _api.get('/api/templates/$templateId');
      return TemplateModel.fromJson(json['template'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<TemplateModel> createTemplate(
      String companyId, TemplateModel template) async {
    final json = await _api.post('/api/templates', body: template.toJson());
    return TemplateModel.fromJson(json['template'] as Map<String, dynamic>);
  }

  @override
  Future<void> updateTemplate(String companyId, TemplateModel template) async {
    await _api.put('/api/templates/${template.id}', body: template.toJson());
  }

  @override
  Future<void> deleteTemplate(String companyId, String templateId) async {
    await _api.delete('/api/templates/$templateId');
  }

  @override
  Stream<List<TemplateModel>> watchTemplates(
    String companyId, {
    TemplateType? type,
  }) async* {
    final result = await fetchTemplates(companyId, type: type);
    yield result.items;
  }

  @override
  Future<List<TemplateModel>> fetchPresetTemplates() async {
    final json = await _api.get('/api/presets');
    return (json['presets'] as List<dynamic>? ?? [])
        .map((e) => TemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TemplateModel> duplicateTemplate(
    String companyId,
    String templateId,
    String newName,
  ) async {
    final json = await _api.post(
      '/api/templates/$templateId/duplicate',
      body: {'name': newName},
    );
    final newId = json['id'] as String;
    final created = await fetchTemplate(companyId, newId);
    return created!;
  }

  @override
  Future<void> renameTemplate(
      String companyId, String templateId, String name) async {
    await _api.patch('/api/templates/$templateId/rename', body: {'name': name});
  }

}
