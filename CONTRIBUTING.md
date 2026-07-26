# Contributing to Aesir

Thank you for your interest in contributing to Aesir! This document outlines the development workflow using Jujutsu (jj) version control system, coding standards, and best practices for contributing to this Ragnarok Online server emulator.

## Using AI Tools

AI assistants (Copilot, Claude, ChatGPT, Cursor, and similar) are welcome here. They are not a shortcut around the bar every contribution has to clear, though. If you use one, **you** are the author and you are fully responsible for what you submit. The rules below are heavily inspired by [curl's stance on AI use](https://curl.se/dev/contribute.html#on-ai-use-in-curl).

### You own the contribution

- Understand every line you submit. You must be able to explain and defend it in review as if you had written it by hand.
- Do not paste raw AI output. AI tends to be verbose, adds comments that explain the obvious, and invents details. Trim it down to match our style: early returns over nested `if`s, no superfluous comments, critical paths that fail loudly rather than papering over errors.
- If a reviewer can tell a change was AI-generated and that you do not fully grasp it, you have more work to do before it is ready.

## Development Workflow with Jujutsu

Aesir uses [Jujutsu](https://jj-vcs.github.io/jj/latest/) (jj) backed by Git for version control. Jujutsu provides a more intuitive and powerful version control experience compared to traditional Git workflows.

### Initial Setup

1. **Install Jujutsu**: Follow the installation instructions at https://jj-vcs.github.io/jj/latest/install/

2. **Clone the repository**:
   ```bash
   jj git clone https://github.com/ygorcastor/aesir.git
   cd aesir
   ```

3. **Set up the development environment**:
   ```bash
   mix deps.get
   mix compile
   ```

### Feature Development Workflow

#### 1. Starting a New Feature

Before starting work on a new feature or bug fix:

```bash
# Create a new change for your feature
jj new -m "feat: implement new feature description"

# Alternatively, create a bookmark for easier tracking
jj bookmark create feature/your-feature-name
```

#### 2. Development Cycle

Jujutsu treats the working directory as a commit, making development more fluid:

```bash
# View current status
jj log

# Make your code changes...

# View what you've changed
jj diff

# Add a meaningful commit message to your change
jj describe -m "feat: detailed description of what you implemented

- Added new packet handler for login flow
- Implemented session validation
- Updated tests for edge cases"

# Continue making changes in the same commit or create a new one
jj new -m "fix: address review feedback"
```

#### 3. Keeping Changes Clean

Use Jujutsu's powerful editing features to maintain clean history:

```bash
# Combine multiple commits into one
jj squash -r <commit-id>

# Edit a previous commit
jj edit <commit-id>
# Make changes, then return to working copy
jj edit @

# Rebase changes interactively
jj rebase -i -d master

# View operation history (useful for undoing mistakes)
jj op log

# Undo the last operation if needed
jj undo
```

#### 4. Code Quality Checks

Before submitting your changes, ensure code quality:

```bash
# Format code
mix format

# Run linting
mix credo --strict

# Run tests
mix test

# Run all quality checks
mix format && mix credo --strict && mix test
```

#### 5. Preparing for Review

When your feature is ready:

```bash
# Ensure your changes are on top of latest master
jj rebase -d master

# Create a clean, descriptive commit message
jj describe -m "feat: implement character movement validation

This commit adds comprehensive validation for character movement
packets to prevent cheating and ensure proper game mechanics:

- Added position validation against map boundaries
- Implemented speed checks to prevent teleporting
- Added unit tests with 95% coverage
- Updated documentation for packet handlers

Closes #123"

# Push to your fork
jj git push --remote origin --branch your-feature-name
```


I really prefer if you make smaller commits, and don't squash them, it makes it easier
for me to review. Feel free to rewrite the history, just keep commits self contained.

## Code Standards

### Elixir Code Style

- **Formatting**: Always run `mix format` before committing. The project uses a `.formatter.exs` configuration.
- **Linting**: Follow all Credo rules. Run `mix credo --strict` to ensure compliance.
- **Documentation**: Add `@moduledoc` and `@doc` to all public modules and functions.
- **Typespecs**: Add `@spec` annotations to all public functions.
- **Testing**: Write comprehensive tests with good coverage for all new functionality.

### Naming Conventions

- Use `snake_case` for variables, functions, and atoms
- Use `CamelCase` for module names
- Use descriptive names that clearly indicate purpose
- Prefix test modules with the module being tested plus `Test`

### Error Handling

- Use `{:ok, result}` and `{:error, reason}` pattern for function returns
- Prefer `with` statements for complex logic paths over nested case statements
- Document all possible error conditions in function specs
- Avoid raising exceptions for normal control flow

## Testing Guidelines

### Test Structure

- Use the appropriate test case: `ExUnit.Case`, `Aesir.DataCase`, etc.
- Use descriptive test names that explain the scenario being tested
- Group related tests using `describe` blocks

### Test Coverage

- Aim for high test coverage, especially for critical paths
- Test both happy path and error conditions
- Include edge cases and boundary conditions
- Mock external dependencies appropriately using `Mimic`
- Try to keep tests as async as possible, see mimic 'mimic_from_context'

## Ragnarok Online Mechanics

### Source of Truth

- If you want, you can use rAthena as reference, they are pretty on par with the correct mechanics, and always give credits
  if you do that!
- Focus on Renewal mechanics unless specifically implementing pre-Renewal features
- Verify formulas and calculations against rAthena source code
- Document any deviations or simplifications from official mechanics

### Implementation Priorities

1. **Correctness**: Ensure mechanics work as intended in the official game
2. **Security**: Validate all client input to prevent cheating
3. **Performance**: Consider the impact on server performance, especially for frequently used systems
4. **Maintainability**: Write clear, well-documented code that other developers can understand

## Commit Message Guidelines

Use conventional commit format:

```
type(scope): subject

body

footer
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process, tooling changes

### Examples
```
feat(zone): implement player movement validation

Add comprehensive validation for character movement packets to prevent
speed hacking and teleportation exploits.

- Validate movement speed against character stats
- Check path validity on server side  
- Add integration tests for movement system

Closes #123
```

## Getting Help

- **Documentation**: Check the project's README and code documentation
- **Issues**: Search existing GitHub issues before creating new ones
- **Discussions**: Use GitHub Discussions for questions and general discussion
- **Code Review**: Be open to feedback and iterate on your changes

## Review Process

1. **Self-review**: Review your own code before requesting review
2. **Quality checks**: Ensure all tests pass and code is properly formatted
3. **Documentation**: Update relevant documentation if needed
4. **Small changes**: Keep pull requests focused and reasonably sized
5. **Responsiveness**: Respond to review feedback promptly

## Resources

- [Jujutsu Tutorial](https://jj-vcs.github.io/jj/latest/tutorial/)

Thank you for contributing to Aesir! 🎮
