# GPTScript Credential Store Configuration

Source: `obot-platform/gptscript-credential-database`

---

## Supported Stores

### SQLite (Development)

```bash
export GPTSCRIPT_SQLITE_FILE=/path/to/credentials.db
```

**Default Locations**:

- macOS: `~/Library/Application Support/gptscript/credentials.db`
- Linux: `$XDG_CONFIG_HOME/gptscript/credentials.db`

### PostgreSQL (Production)

```bash
export GPTSCRIPT_POSTGRES_DSN="postgresql://user:pass@host:5432/dbname"
```

---

## Encryption Configuration

**IMPORTANT**: Credentials stored **unencrypted** by default.

### Encryption Config File

**Locations**:

- macOS: `~/Library/Application Support/gptscript/encryptionconfig.yaml`
- Linux: `$XDG_CONFIG_HOME/gptscript/encryptionconfig.yaml`

**Override**:

```bash
export GPTSCRIPT_ENCRYPTION_CONFIG_FILE=/path/to/encryptionconfig.yaml
```

### Config Format

Kubernetes-compatible encryption configuration:

```yaml
kind: EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
resources:
  - resources:
      - credentials                     # MUST be exact
    providers:
      - aesgcm:
          keys:
            - name: myKey
              secret: <base64-key>      # openssl rand -base64 32
```

**Supported Providers**:

- **aesgcm**: AES-GCM with local key (tested, recommended)
- **KMS v2**: Kubernetes KMS providers (untested)

---

## Obot Integration

### Development

```bash
export GPTSCRIPT_SQLITE_FILE=./credentials.db
```

### Production (Kubernetes)

**Create secret**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gptscript-encryption
stringData:
  encryptionconfig.yaml: |
    kind: EncryptionConfiguration
    apiVersion: apiserver.config.k8s.io/v1
    resources:
      - resources: [credentials]
        providers:
          - aesgcm:
              keys:
                - name: primary
                  secret: <base64-key>
```

**Mount in deployment**:

```yaml
env:
  - name: GPTSCRIPT_POSTGRES_DSN
    valueFrom:
      secretKeyRef:
        name: obot-db
        key: dsn
  - name: GPTSCRIPT_ENCRYPTION_CONFIG_FILE
    value: /etc/gptscript/encryptionconfig.yaml
volumeMounts:
  - name: encryption-config
    mountPath: /etc/gptscript
volumes:
  - name: encryption-config
    secret:
      secretName: gptscript-encryption
```

---

## Troubleshooting

**Credentials not persisting**:

- Verify DSN: `psql $GPTSCRIPT_POSTGRES_DSN`
- Check SQLite file permissions
- Verify database tables exist

**Decryption failures**:

- Ensure encryption config matches original
- Verify `resources` array contains `credentials` exactly
- Check key rotation hasn't occurred without re-encryption
