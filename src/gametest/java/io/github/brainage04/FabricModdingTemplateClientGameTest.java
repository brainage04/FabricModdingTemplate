package io.github.brainage04;

import io.github.brainage04.command.ExampleCommand;
import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestSingleplayerContext;

@SuppressWarnings("UnstableApiUsage")
public class FabricModdingTemplateClientGameTest implements FabricClientGameTest {
    @Override
    public void runTest(ClientGameTestContext context) {
        try (TestSingleplayerContext singleplayer = context.worldBuilder().create()) {
            singleplayer.getClientWorld().waitForChunksRender();

            context.computeOnClient(client -> {
                if (client.level == null) {
                    throw new AssertionError("Expected a client world to be loaded for the client GameTest.");
                }

                if (client.player == null) {
                    throw new AssertionError("Expected a client player to exist in the client GameTest.");
                }

                return null;
            });

            singleplayer.getServer().computeOnServer(server -> {
                if (server.getCommands().getDispatcher().getRoot().getChild(ExampleCommand.COMMAND_NAME) == null) {
                    throw new AssertionError("Expected the example command to be registered in the integrated server.");
                }

                return null;
            });
        }
    }
}
