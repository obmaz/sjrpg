String? readCheckpoint() => null;
bool writeCheckpoint(String value) => true;
void clearCheckpoint() {}
void Function() listenForExit(void Function() save) => () {};
