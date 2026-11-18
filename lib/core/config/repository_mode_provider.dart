import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'repository_mode_provider.g.dart';

@Riverpod(keepAlive: true)
bool useApiRepositories(Ref ref) => false;
