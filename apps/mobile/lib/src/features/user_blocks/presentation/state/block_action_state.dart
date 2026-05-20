import 'package:equatable/equatable.dart';

sealed class BlockActionState extends Equatable {
  const BlockActionState();

  @override
  List<Object?> get props => [];
}

class BlockActionIdle extends BlockActionState {
  const BlockActionIdle();
}

class BlockActionBlocking extends BlockActionState {
  const BlockActionBlocking();
}

class BlockActionSuccess extends BlockActionState {
  const BlockActionSuccess();
}

class BlockActionFailure extends BlockActionState {
  const BlockActionFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
