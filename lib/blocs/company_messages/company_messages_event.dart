abstract class CompanyMessagesEvent {
  const CompanyMessagesEvent();
}

class LoadCompanyMessages extends CompanyMessagesEvent {}

class ArchiveCompanyMessages extends CompanyMessagesEvent {
  final List<int> indices;

  const ArchiveCompanyMessages(this.indices);
}

class UnarchiveCompanyMessages extends CompanyMessagesEvent {
  final List<int> indices;

  const UnarchiveCompanyMessages(this.indices);
}
