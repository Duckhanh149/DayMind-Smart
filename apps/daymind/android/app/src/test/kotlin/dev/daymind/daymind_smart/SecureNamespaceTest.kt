package dev.daymind.daymind_smart

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SecureNamespaceTest {
    @Test fun explicitBackendKeysKeepLegacyKeysAndRejectPaths() {
        for (name in listOf("session", "installation", "test_probe", "offline.session",
            "offline.installation", "production.daymind-ci.session", "production.daymind-ci.installation")) {
            assertTrue(validSessionKey(name))
        }
        for (name in listOf(null, "../session", "production.other/owner.session", "production.a.session",
            "production.daymind-ci.secret", "offline.test_probe", "production.DAYMIND.session")) {
            assertFalse(validSessionKey(name))
        }
    }
}
