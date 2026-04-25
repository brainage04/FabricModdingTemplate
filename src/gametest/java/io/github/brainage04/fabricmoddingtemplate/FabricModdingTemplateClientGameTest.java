package io.github.brainage04.fabricmoddingtemplate;

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;

@SuppressWarnings("UnstableApiUsage")
public class FabricModdingTemplateClientGameTest implements FabricClientGameTest {
    @Override
    public void runTest(ClientGameTestContext context) {
        context.computeOnClient(client -> {
            if (!FabricModdingTemplateClient.isInitialized()) {
                throw new AssertionError("Expected the client initializer to run before the client GameTest.");
            }

            if (client.options == null) {
                throw new AssertionError("Expected client options to be available during the client GameTest.");
            }

            return null;
        });
    }
}
