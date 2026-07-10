/// Cursor 全局认证与设备指纹快照（对应 state.vscdb + storage.json）
class CursorAuthSnapshot {
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final String? membershipType;
  final String? signUpType;
  final String? machineId;
  final String? macMachineId;
  final String? devDeviceId;
  final String? sqmId;

  const CursorAuthSnapshot({
    this.email,
    this.accessToken,
    this.refreshToken,
    this.membershipType,
    this.signUpType,
    this.machineId,
    this.macMachineId,
    this.devDeviceId,
    this.sqmId,
  });

  bool get hasAuth =>
      (accessToken?.isNotEmpty ?? false) || (refreshToken?.isNotEmpty ?? false);

  bool get hasDeviceIds =>
      (machineId?.isNotEmpty ?? false) ||
      (macMachineId?.isNotEmpty ?? false) ||
      (devDeviceId?.isNotEmpty ?? false) ||
      (sqmId?.isNotEmpty ?? false);

  CursorAuthSnapshot copyWith({
    String? email,
    String? accessToken,
    String? refreshToken,
    String? membershipType,
    String? signUpType,
    String? machineId,
    String? macMachineId,
    String? devDeviceId,
    String? sqmId,
  }) {
    return CursorAuthSnapshot(
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      membershipType: membershipType ?? this.membershipType,
      signUpType: signUpType ?? this.signUpType,
      machineId: machineId ?? this.machineId,
      macMachineId: macMachineId ?? this.macMachineId,
      devDeviceId: devDeviceId ?? this.devDeviceId,
      sqmId: sqmId ?? this.sqmId,
    );
  }
}
