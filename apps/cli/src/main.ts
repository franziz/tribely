import { Command } from 'commander';
import pkg from '../package.json' with { type: 'json' };

const program = new Command();

program
  .name('tribely')
  .description('Tribely operator CLI — manages the Tribely API over HTTP')
  .version(pkg.version);

await program.parseAsync();
