abstract class MessagesEvent {
  const MessagesEvent();
}

class LoadMessages extends MessagesEvent {}

class ArchiveMessages extends MessagesEvent {
  final List<int> indices;

  const ArchiveMessages(this.indices);
}

class UnarchiveMessages extends MessagesEvent {
  final List<int> indices;

  const UnarchiveMessages(this.indices);
}
