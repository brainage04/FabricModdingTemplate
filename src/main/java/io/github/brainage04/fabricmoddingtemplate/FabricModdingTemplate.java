package io.github.brainage04.fabricmoddingtemplate;

import io.github.brainage04.fabricmoddingtemplate.command.core.ModCommands;
import io.github.brainage04.fabricmoddingtemplate.config.ExampleConfig;
import net.fabricmc.api.ModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class FabricModdingTemplate implements ModInitializer {
    public static final String MOD_ID = "fabricmoddingtemplate";
    public static final String MOD_NAME = "FabricModdingTemplate";
	public static final Logger LOGGER = LoggerFactory.getLogger(MOD_NAME);

	@Override
	public void onInitialize() {
        LOGGER.info("{} initialising...", MOD_NAME);

        ExampleConfig.init();
        ModCommands.initialize();

        if (ExampleConfig.CONFIG.logConfigOnStartup.get()) {
            LOGGER.info(
                    "Loaded config: message='{}', mode={}, featuredItem={}, retries={}",
                    ExampleConfig.CONFIG.welcomeMessage.get(),
                    ExampleConfig.CONFIG.syncMode.get(),
                    ExampleConfig.CONFIG.featuredItem.get(),
                    ExampleConfig.CONFIG.startupRetries.get()
            );
        }

        LOGGER.info("{} initialised.", MOD_NAME);
	}
}
