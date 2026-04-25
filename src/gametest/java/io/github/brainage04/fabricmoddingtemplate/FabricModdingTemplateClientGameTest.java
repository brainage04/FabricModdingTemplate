package io.github.brainage04.fabricmoddingtemplate;

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestDedicatedServerContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestServerConnection;

import java.util.Properties;

@SuppressWarnings("UnstableApiUsage")
public class FabricModdingTemplateClientGameTest implements FabricClientGameTest {
    @Override
    public void runTest(ClientGameTestContext context) {
        Properties serverProperties = new Properties();
        serverProperties.setProperty("simulation-distance", "5");
        serverProperties.setProperty("view-distance", "2");

        try (TestDedicatedServerContext server = context.worldBuilder().createServer(serverProperties);
             TestServerConnection ignored = server.connect()) {
            context.computeOnClient(client -> {
                if (!FabricModdingTemplateClient.isInitialized()) {
                    throw new AssertionError("Expected the client initializer to run before the client GameTest.");
                }

                if (client.level == null) {
                    throw new AssertionError("Expected the client to be connected to a world during the client GameTest.");
                }

                if (client.player == null) {
                    throw new AssertionError("Expected the client player to be available during the client GameTest.");
                }

                return null;
            });

            context.waitTicks(20);
        }
    }
}
