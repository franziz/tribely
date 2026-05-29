/**
 * Minimal interactive prompt helpers using Node's built-in readline.
 *
 * No third-party prompt libraries — readline/promises is sufficient for
 * the two input types we need: plain text (email) and masked password.
 */

import * as readline from 'node:readline/promises';
import { stdin, stdout, stderr } from 'node:process';

/**
 * Prompt for a plain-text value (e.g. email address).
 * Echoes input as normal.
 */
export async function promptText(label: string): Promise<string> {
  const rl = readline.createInterface({ input: stdin, output: stdout });
  try {
    return await rl.question(`${label}: `);
  } finally {
    rl.close();
  }
}

/**
 * Prompt for a password with echo suppressed.
 *
 * Implementation: mute stdout during input by temporarily replacing the
 * readline interface's `_writeToOutput` method so keystrokes are not echoed.
 * This is a well-known pattern for Node readline password prompts and avoids
 * requiring inquirer or any other dependency.
 */
export async function promptPassword(label: string): Promise<string> {
  const rl = readline.createInterface({ input: stdin, output: stderr });

  // Suppress echo by overriding the internal output write method.
  // The cast is required because _writeToOutput is not in Node's public typings.
  (rl as unknown as { _writeToOutput: (s: string) => void })._writeToOutput = (
    s: string,
  ): void => {
    // Only write the prompt label itself (ends with ': '), not any keystrokes.
    if (s.endsWith(': ')) {
      stderr.write(s);
    }
  };

  try {
    return await rl.question(`${label}: `);
  } finally {
    rl.close();
    // Emit a newline so the next output starts on a fresh line.
    stderr.write('\n');
  }
}
