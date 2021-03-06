// Copyright 2018 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' show ProcessResult;

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:fuchsia_remote_debug_protocol/src/runners/ssh_command_runner.dart';

void main() {
  group('SshCommandRunner.constructors', () {
    test('throws exception with invalid address', () async {
      SshCommandRunner newCommandRunner() {
        return new SshCommandRunner(address: 'sillyaddress.what');
      }

      expect(newCommandRunner, throwsArgumentError);
    });

    test('throws exception from injection constructor with invalid addr',
        () async {
      SshCommandRunner newCommandRunner() {
        return new SshCommandRunner.withProcessManager(
            const LocalProcessManager(),
            address: '192.168.1.1.1');
      }

      expect(newCommandRunner, throwsArgumentError);
    });
  });

  group('SshCommandRunner.run', () {
    MockProcessManager mockProcessManager;
    MockProcessResult mockProcessResult;
    SshCommandRunner runner;

    setUp(() {
      mockProcessManager = new MockProcessManager();
      mockProcessResult = new MockProcessResult();
      when(mockProcessManager.run(typed(any))).thenReturn(
          new Future<MockProcessResult>.value(mockProcessResult));
    });

    test('verify interface is appended to ipv6 address', () async {
      const String ipV6Addr = 'fe80::8eae:4cff:fef4:9247';
      const String interface = 'eno1';
      runner = new SshCommandRunner.withProcessManager(
        mockProcessManager,
        address: ipV6Addr,
        interface: interface,
        sshConfigPath: '/whatever',
      );
      when<String>(mockProcessResult.stdout).thenReturn('somestuff');
      when(mockProcessResult.exitCode).thenReturn(0);
      await runner.run('ls /whatever');
      final List<String> passedCommand =
          verify(mockProcessManager.run(typed(captureAny))).captured.single;
      expect(passedCommand, contains('$ipV6Addr%$interface'));
    });

    test('verify no percentage symbol is added when no ipv6 interface',
        () async {
      const String ipV6Addr = 'fe80::8eae:4cff:fef4:9247';
      runner = new SshCommandRunner.withProcessManager(
        mockProcessManager,
        address: ipV6Addr,
      );
      when<String>(mockProcessResult.stdout).thenReturn('somestuff');
      when(mockProcessResult.exitCode).thenReturn(0);
      await runner.run('ls /whatever');
      final List<String> passedCommand =
          verify(mockProcessManager.run(typed(captureAny))).captured.single;
      expect(passedCommand, contains(ipV6Addr));
    });

    test('verify commands are split into multiple lines', () async {
      const String addr = '192.168.1.1';
      runner = new SshCommandRunner.withProcessManager(mockProcessManager,
          address: addr);
      when<String>(mockProcessResult.stdout).thenReturn('''this
          has
          four
          lines''');
      when(mockProcessResult.exitCode).thenReturn(0);
      final List<String> result = await runner.run('oihaw');
      expect(result, hasLength(4));
    });

    test('verify exception on nonzero process result exit code', () async {
      const String addr = '192.168.1.1';
      runner = new SshCommandRunner.withProcessManager(mockProcessManager,
          address: addr);
      when<String>(mockProcessResult.stdout).thenReturn('whatever');
      when(mockProcessResult.exitCode).thenReturn(1);
      Future<Null> failingFunction() async {
        await runner.run('oihaw');
      }

      expect(failingFunction, throwsA(const isInstanceOf<SshCommandError>()));
    });

    test('verify correct args with config', () async {
      const String addr = 'fe80::8eae:4cff:fef4:9247';
      const String config = '/this/that/this/and/uh';
      runner = new SshCommandRunner.withProcessManager(
        mockProcessManager,
        address: addr,
        sshConfigPath: config,
      );
      when<String>(mockProcessResult.stdout).thenReturn('somestuff');
      when(mockProcessResult.exitCode).thenReturn(0);
      await runner.run('ls /whatever');
      final List<String> passedCommand =
          verify(mockProcessManager.run(typed(captureAny))).captured.single;
      expect(passedCommand, contains('-F'));
      final int indexOfFlag = passedCommand.indexOf('-F');
      final String passedConfig = passedCommand[indexOfFlag + 1];
      expect(passedConfig, config);
    });

    test('verify config is excluded correctly', () async {
      const String addr = 'fe80::8eae:4cff:fef4:9247';
      runner = new SshCommandRunner.withProcessManager(
        mockProcessManager,
        address: addr,
      );
      when<String>(mockProcessResult.stdout).thenReturn('somestuff');
      when(mockProcessResult.exitCode).thenReturn(0);
      await runner.run('ls /whatever');
      final List<String> passedCommand =
          verify(mockProcessManager.run(typed(captureAny))).captured.single;
      final int indexOfFlag = passedCommand.indexOf('-F');
      expect(indexOfFlag, equals(-1));
    });
  });
}

class MockProcessManager extends Mock implements ProcessManager {}

class MockProcessResult extends Mock implements ProcessResult {}
