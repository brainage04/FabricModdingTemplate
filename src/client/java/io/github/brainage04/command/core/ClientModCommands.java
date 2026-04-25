package io.github.brainage04.command.core;

import io.github.brainage04.command.ExampleClientCommand;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;

public class ClientModCommands {
    public static void initialize() {
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            ExampleClientCommand.initialize(dispatcher);
        });
    }
}
