import 'package:flutter/material.dart';

import '../account/account_controller.dart';
import '../account/turnstile_field.dart';
import '../analytics/day_format.dart';
import '../components/empty_state.dart';
import '../components/surface_card.dart';
import '../config/build_config.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../environment/space_weather.dart' show formatAge;
import '../navigation/modules.dart';
import '../sync/sync_controller.dart';
import 'page_frame.dart';

/// Sign-in, the RAKIA account, and the optional backup of readings.
/// Readings stay on the device unless the astronaut turns backup on.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.module, this.turnstileSiteKey});

  final ModuleSpec module;

  /// Defaults to the build's site key; tests supply one.
  final String? turnstileSiteKey;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final siteKey = turnstileSiteKey ?? kTurnstileSiteKey;
    final Widget body = switch (account.status) {
      AccountStatus.unavailable => EmptyState(
        icon: module.selectedIcon,
        title: module.emptyTitle,
        message: module.emptyMessage,
      ),
      AccountStatus.restoring => const _Restoring(),
      AccountStatus.signedOut => _SignedOut(account: account, siteKey: siteKey),
      AccountStatus.needsAccount => _NeedsAccount(
        account: account,
        siteKey: siteKey,
      ),
      AccountStatus.signedIn => _SignedIn(account: account),
    };
    return PageFrame(
      title: module.label,
      eyebrow: module.group.label,
      summary: module.summary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (account.usesEmulator) ...[
            const _Note(
              key: Key('account-emulator'),
              text:
                  'Development build: sign-in uses a local Firebase Auth '
                  'emulator, not real accounts.',
            ),
            const SizedBox(height: RakiaSpacing.lg),
          ],
          body,
          if (account.status == AccountStatus.signedIn) ...[
            const SizedBox(height: RakiaSpacing.lg),
            const BackupCard(),
          ],
          const SizedBox(height: RakiaSpacing.lg),
          const _Note(
            text:
                'Your readings stay on this device. Signing in does not upload '
                'them; only turning on backup does.',
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RakiaColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 20, color: c.textSecondary),
        const SizedBox(width: RakiaSpacing.sm),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _Restoring extends StatelessWidget {
  const _Restoring();

  @override
  Widget build(BuildContext context) => const SurfaceCard(
    title: 'Restoring your sign-in',
    leadingIcon: Icons.person_outline,
    child: LinearProgressIndicator(semanticsLabel: 'Restoring your sign-in'),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String? text;

  @override
  Widget build(BuildContext context) {
    final t = text;
    if (t == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: RakiaSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: Text(
          key: const Key('account-error'),
          t,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

enum _Mode { signIn, create, reset }

class _SignedOut extends StatefulWidget {
  const _SignedOut({required this.account, required this.siteKey});
  final AccountController account;
  final String siteKey;

  @override
  State<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends State<_SignedOut> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  String? _turnstile;
  String? _sent;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final a = widget.account;
    switch (_mode) {
      case _Mode.signIn:
        await a.signIn(_email.text, _password.text);
      case _Mode.create:
        final token = _turnstile;
        if (token == null) return;
        // A token is single-use: whatever happens, a new check is needed.
        setState(() => _turnstile = null);
        await a.signUp(_email.text, _password.text, turnstileToken: token);
      case _Mode.reset:
        await a.sendPasswordReset(_email.text);
        if (mounted && a.error == null) {
          setState(
            () => _sent =
                'If an account exists for ${_email.text.trim()}, a reset link '
                'is on its way.',
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final t = Theme.of(context).textTheme;
    final canCreate = widget.siteKey.isNotEmpty && turnstileSupported;
    final ready = switch (_mode) {
      _Mode.signIn => true,
      _Mode.create => _turnstile != null,
      _Mode.reset => true,
    };
    final title = switch (_mode) {
      _Mode.signIn => 'Sign in',
      _Mode.create => 'Create your account',
      _Mode.reset => 'Reset your password',
    };
    return SurfaceCard(
      key: const Key('account-signed-out'),
      title: title,
      subtitle: 'Email and password',
      leadingIcon: Icons.person_outline,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('account-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (_mode != _Mode.reset) ...[
              const SizedBox(height: RakiaSpacing.md),
              TextField(
                key: const Key('account-password'),
                controller: _password,
                obscureText: true,
                autofillHints: [
                  _mode == _Mode.create
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _mode == _Mode.create
                      ? 'At least 8 characters'
                      : null,
                ),
                onSubmitted: (_) => a.busy || !ready ? null : _submit(),
              ),
            ],
            if (_mode == _Mode.create) ...[
              const SizedBox(height: RakiaSpacing.lg),
              if (canCreate)
                TurnstileField(
                  siteKey: widget.siteKey,
                  onToken: (tok) => setState(() => _turnstile = tok),
                )
              else if (!turnstileSupported)
                TurnstileField(siteKey: widget.siteKey, onToken: (_) {})
              else
                Text(
                  'Account creation is not available in this build.',
                  style: t.bodyMedium,
                ),
            ],
            if (_mode == _Mode.create && !canCreate)
              const SizedBox.shrink()
            else ...[
              const SizedBox(height: RakiaSpacing.lg),
              FilledButton(
                key: const Key('account-submit'),
                onPressed: a.busy || !ready ? null : _submit,
                child: Text(switch (_mode) {
                  _Mode.signIn => a.busy ? 'Signing in' : 'Sign in',
                  _Mode.create => a.busy ? 'Creating' : 'Create account',
                  _Mode.reset => 'Send reset link',
                }),
              ),
            ],
            _ErrorText(a.error),
            if (_sent case final s? when _mode == _Mode.reset) ...[
              const SizedBox(height: RakiaSpacing.md),
              Text(key: const Key('account-reset-sent'), s),
            ],
            const SizedBox(height: RakiaSpacing.md),
            Wrap(
              spacing: RakiaSpacing.sm,
              children: [
                if (_mode != _Mode.signIn)
                  TextButton(
                    key: const Key('account-mode-signin'),
                    onPressed: () => setState(() => _mode = _Mode.signIn),
                    child: const Text('I have an account'),
                  ),
                if (_mode != _Mode.create)
                  TextButton(
                    key: const Key('account-mode-create'),
                    onPressed: () => setState(() {
                      _mode = _Mode.create;
                      _turnstile = null;
                    }),
                    child: const Text('Create an account'),
                  ),
                if (_mode != _Mode.reset)
                  TextButton(
                    key: const Key('account-mode-reset'),
                    onPressed: () => setState(() => _mode = _Mode.reset),
                    child: const Text('Forgot password'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedsAccount extends StatefulWidget {
  const _NeedsAccount({required this.account, required this.siteKey});
  final AccountController account;
  final String siteKey;

  @override
  State<_NeedsAccount> createState() => _NeedsAccountState();
}

class _NeedsAccountState extends State<_NeedsAccount> {
  String? _turnstile;
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final canCreate = widget.siteKey.isNotEmpty && turnstileSupported;
    return SurfaceCard(
      key: const Key('account-needs-account'),
      title: 'Finish creating your RAKIA account',
      subtitle: 'Signed in as ${a.session?.email ?? ''}',
      leadingIcon: Icons.person_add_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your sign-in exists, but your RAKIA account has not been created '
            'yet. Complete the check below to create it.',
          ),
          const SizedBox(height: RakiaSpacing.lg),
          TurnstileField(
            key: ValueKey('turnstile-$_attempt'),
            siteKey: widget.siteKey,
            onToken: (tok) => setState(() => _turnstile = tok),
          ),
          const SizedBox(height: RakiaSpacing.lg),
          Wrap(
            spacing: RakiaSpacing.sm,
            runSpacing: RakiaSpacing.sm,
            children: [
              if (canCreate)
                FilledButton(
                  key: const Key('account-create'),
                  onPressed: a.busy || _turnstile == null
                      ? null
                      : () async {
                          final token = _turnstile!;
                          setState(() {
                            _turnstile = null;
                            _attempt++;
                          });
                          await a.createAccount(token);
                        },
                  child: Text(a.busy ? 'Creating' : 'Create RAKIA account'),
                ),
              OutlinedButton(
                key: const Key('account-sign-out'),
                onPressed: a.busy ? null : a.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
          _ErrorText(a.error),
        ],
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.account});
  final AccountController account;

  static String _role(String r) => switch (r) {
    'astronaut' => 'Astronaut',
    'crew_medical_officer' => 'Crew medical officer',
    'flight_surgeon' => 'Flight surgeon',
    'researcher' => 'Researcher',
    'mission_admin' => 'Mission administrator',
    _ => r,
  };

  @override
  Widget build(BuildContext context) {
    final a = account;
    final s = a.session;
    final acc = a.account;
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final verified = s?.emailVerified ?? false;
    return SurfaceCard(
      key: const Key('account-signed-in'),
      title: s?.email ?? 'Signed in',
      subtitle: acc == null
          ? 'Account details are unavailable right now'
          : 'RAKIA account since ${formatDay(acc.createdAt.toUtc())}',
      leadingIcon: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.mark_email_read_outlined : Icons.mail_outline,
                size: 20,
                color: verified ? c.statusWithinBaseline : c.statusWatch,
              ),
              const SizedBox(width: RakiaSpacing.sm),
              Expanded(
                child: Text(
                  key: const Key('account-verified'),
                  verified
                      ? 'Email verified'
                      : 'Email not verified yet. Open the link we sent you.',
                ),
              ),
            ],
          ),
          if (!verified) ...[
            const SizedBox(height: RakiaSpacing.sm),
            Wrap(
              spacing: RakiaSpacing.sm,
              children: [
                TextButton(
                  key: const Key('account-resend'),
                  onPressed: a.busy ? null : a.resendVerification,
                  child: const Text('Send the link again'),
                ),
                TextButton(
                  key: const Key('account-recheck'),
                  onPressed: a.busy ? null : a.refreshVerification,
                  child: const Text('I have verified it'),
                ),
              ],
            ),
          ],
          const SizedBox(height: RakiaSpacing.md),
          Text('Mission roles', style: t.titleSmall),
          const SizedBox(height: RakiaSpacing.xs),
          if (acc == null || acc.roles.isEmpty)
            Text(
              'No mission roles yet. A mission administrator adds you to a '
              'mission.',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            )
          else
            for (final r in acc.roles)
              Text(
                '${r.missionName}${r.isSimulation ? ' (simulation)' : ''}: '
                '${_role(r.role)}',
              ),
          const SizedBox(height: RakiaSpacing.lg),
          OutlinedButton.icon(
            key: const Key('account-sign-out'),
            onPressed: a.busy ? null : a.signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
          _ErrorText(a.error),
          if (!a.persistent) ...[
            const SizedBox(height: RakiaSpacing.md),
            Text(
              'This browser cannot keep data, so you will need to sign in '
              'again next time.',
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opt-in backup of the astronaut's own readings to the RAKIA server.
class BackupCard extends StatelessWidget {
  const BackupCard({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.of(context);
    final t = Theme.of(context).textTheme;
    final c = RakiaColors.of(context);
    final status = sync.status;
    final canToggle =
        status != SyncStatus.unavailable && status != SyncStatus.needsStorage;
    final String line = switch (status) {
      SyncStatus.unavailable => 'Backup is not available in this build.',
      SyncStatus.needsStorage =>
        'This browser cannot keep data between visits, so there is no '
            'lasting record to back up.',
      SyncStatus.off => 'Off. Nothing has been sent from this device.',
      SyncStatus.needsSignIn => 'Sign in to back up.',
      SyncStatus.syncing =>
        'Backing up: ${sync.backedUp} of ${sync.total} readings.',
      SyncStatus.failed =>
        '${sync.backedUp} of ${sync.total} readings backed up. The last '
            'attempt failed: ${sync.error}',
      SyncStatus.idle =>
        sync.total == 0
            ? 'On. There are no readings to back up yet.'
            : '${sync.backedUp} of ${sync.total} readings backed up'
                  '${sync.lastSynced == null ? '' : ', last ${formatAge(sync.lastSynced!, now: DateTime.now().toUtc())}'}.',
    };
    return SurfaceCard(
      key: const Key('backup-card'),
      title: 'Back up my readings',
      subtitle: 'Optional, to the RAKIA server',
      leadingIcon: Icons.cloud_upload_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sends a copy of the readings in My health record to the RAKIA '
            'server, where only your account can read them. Each reading '
            'is sent with its tamper-evident hash, and the server checks '
            'every one. Check-ins, reaction tests and simulated data are '
            'never sent. This is a backup: it does not yet restore to '
            'another device, and readings already sent stay on the server '
            'if you turn it off.',
          ),
          const SizedBox(height: RakiaSpacing.sm),
          SwitchListTile(
            key: const Key('backup-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Back up my readings'),
            value: sync.enabled,
            onChanged: canToggle ? sync.setEnabled : null,
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              key: const Key('backup-status'),
              line,
              style: t.bodyMedium?.copyWith(
                color: status == SyncStatus.failed
                    ? Theme.of(context).colorScheme.error
                    : c.textSecondary,
              ),
            ),
          ),
          if (sync.enabled && status != SyncStatus.needsSignIn) ...[
            const SizedBox(height: RakiaSpacing.md),
            OutlinedButton.icon(
              key: const Key('backup-now'),
              onPressed: status == SyncStatus.syncing ? null : sync.syncNow,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Back up now'),
            ),
          ],
        ],
      ),
    );
  }
}
