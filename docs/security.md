# Sécurité de MÏÏghO

## 1. Modèle de menaces
Basé sur STRIDE :
- **Spoofing** : Usurpation de compte (SIM swap).
- **Tampering** : MitM sur Wi-Fi publics.
- **Repudiation** : Traces d'audit insuffisantes pour les transactions financières.
- **Information Disclosure** : Fuites de données personnelles, interceptions.
- **Denial of Service** : Abus d'API, inondation de SMS OTP.
- **Elevation of Privilege** : Contournement des contrôles d'accès.

## 2. Authentification
Flux basé sur Téléphone + OTP SMS :
- Limitation de taux sur l'envoi de SMS (protection anti-brute force).
- Expiration rapide des OTP (ex: 3 minutes).
- Jetons opaques : d'accès (15 min), de rafraîchissement (30 jours, rotatifs).
- Détection d'anomalies (famille de jetons révoquée si usage suspect).

## 3. Chiffrement
- **En transit** : TLS 1.3 obligatoire.
- **Au repos** : AES-256-GCM pour les données sensibles en base de données.
- **Préparation E2E** : Interfaces `EncryptionService`, gestion des clés (Signal Protocol prévu pour Phase 2).

## 4. Protection API
- Rate limiting (par IP et utilisateur via Valkey Token Bucket).
- Validation stricte des entrées (E.164 pour numéros, limites de taille et longueur).
- Whitelist CORS, CSP pour les interfaces web.

## 5. Stockage sécurisé client
- Utilisation de **iOS Keychain** et **Android EncryptedSharedPreferences**.
- Pinning de certificats TLS via NetworkSecurityConfig et TrustKit.

## 6. Gestion des sessions
- Suivi multi-appareils (chaque device a sa session).
- Déconnexion forcée possible par l'utilisateur.
- Alertes de connexions depuis un nouveau pays/appareil.

## 7. Protection contre les attaques communes
- Injections SQL : Requêtes paramétrées via `pgx`.
- XSS : Encodage en sortie, pas de HTML interprété dans l'app mobile.
- Traversal & Uploads : Validation des chemins, magic bytes, limites de taille, whitelist MIME.

## 8. Journalisation et audit
- Logués : Événements d'authentification, actions admin, tentatives échouées.
- Exclus : Mots de passe, tokens, OTP, PII en clair.
- Rétention contrôlée et hachage des logs sensibles.

## 9. Sécurité des données financières
- Journalisation immuable (Ledger partie double).
- Clés d'idempotence pour toutes les opérations financières.
- Vérification de signature pour les webhooks des PSP.

## 10. Conformité
- Respect des lois NDPA (Nigeria), POPIA (Afrique du Sud), Kenya DPA.
- Conformité de base BCEAO/CEMAC.
- Considérations de résidence des données par région.

## 11. Interfaces E2E (Préparation)
```go
package security

type EncryptionService interface {
    Encrypt(plaintext []byte, metadata EncryptionMetadata) ([]byte, error)
    Decrypt(ciphertext []byte, metadata EncryptionMetadata) ([]byte, error)
}

type KeyStore interface {
    SavePreKey(keyID uint32, record []byte) error
    LoadPreKey(keyID uint32) ([]byte, error)
}

type PreKeyBundle struct {
    IdentityKey []byte
    SignedPreKey []byte
    PreKeys [][]byte
}

type EncryptionMetadata struct {
    Algorithm string `json:"algo"`
    KeyID     uint32 `json:"key_id"`
}
```
