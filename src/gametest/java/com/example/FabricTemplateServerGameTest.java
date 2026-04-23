package com.example;

import com.example.command.ExampleCommand;
import net.fabricmc.fabric.api.gametest.v1.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;

public class FabricTemplateServerGameTest {
    @GameTest
    public void exampleCommandIsRegistered(GameTestHelper context) {
        if (context.getLevel().getServer().getCommands().getDispatcher().getRoot().getChild(ExampleCommand.COMMAND_NAME) == null) {
            throw new AssertionError("Expected the example command to be registered on the dedicated server.");
        }

        context.succeed();
    }
}
