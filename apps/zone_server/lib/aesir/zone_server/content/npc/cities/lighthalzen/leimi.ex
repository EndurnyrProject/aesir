defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Leimi do
  @moduledoc """
  Greets visitors while watching for Assassins.

  ## Behavior

  - Adds different dialogue for male and female Assassins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 139,
        y: 48,
        dir: 7,
        sprite: 73,
        name: "Leimi",
        scope: :shared,
        unique_name: "Leimi#mimir"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Leimi]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Leimi]")
      |> mes("Oh...!")
      |> mes("Good heavens!")
      |> mes("Um, may I help you?")
      |> emotion(:huk)

    ctx
    |> respond_to_assassin()
    |> close()
  end

  defp respond_to_assassin(ctx) do
    if base_job(ctx) == :assassin do
      respond_to_assassin(ctx, sex(ctx) == get_char_var(ctx, :SEX_MALE, 0))
    else
      ctx
    end
  end

  defp respond_to_assassin(ctx, true) do
    ctx
    |> next()
    |> mes("[Leimi]")
    |> mes("Oh, you're an Assassin!")
    |> mes("Oh, you boys are soooo cute!")
    |> mes("And so cool and so mysterious all at the same time! I love you!")
  end

  defp respond_to_assassin(ctx, false) do
    ctx
    |> next()
    |> mes("[Leimi]")
    |> mes("An Assassin...?")
    |> mes("Oh, you wouldn't happen")
    |> mes("to know any Assassin boys")
    |> mes("that might be single, do you?")
    |> mes("Oh-my-god, they're hunky-hot~")
  end
end
