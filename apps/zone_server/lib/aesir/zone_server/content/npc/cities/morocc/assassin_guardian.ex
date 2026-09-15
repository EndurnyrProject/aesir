defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.AssassinGuardian do
  @moduledoc """
  Guards the Assassin grounds and challenges trespassers.

  ## Behavior

  - Welcomes Assassins and gives other characters one of four random warnings.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild16",
        x: 195,
        y: 281,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "SinGuard"
      },
      %{
        map: "moc_fild16",
        x: 204,
        y: 281,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "Assassin Guardian#2"
      },
      %{
        map: "moc_fild16",
        x: 207,
        y: 281,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "Assassin Guardian#3"
      },
      %{
        map: "moc_fild16",
        x: 216,
        y: 281,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "Assassin Guardian#4"
      },
      %{
        map: "moc_fild16",
        x: 200,
        y: 231,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "Assassin Guardian#5"
      },
      %{
        map: "moc_fild16",
        x: 211,
        y: 231,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "Assassin Guardian#6"
      },
      %{
        map: "moc_fild16",
        x: 200,
        y: 257,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "Assassin Guardian#7"
      },
      %{
        map: "moc_fild16",
        x: 211,
        y: 257,
        dir: 4,
        sprite: 707,
        name: "Assassin Guardian",
        scope: :shared,
        unique_name: "Assassin Guardian#8"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Assassin Guardian]")

    if base_job(ctx) == :assassin do
      ctx |> mes("Welcome.") |> close()
    else
      warn_trespasser(ctx)
    end
  end

  defp warn_trespasser(ctx) do
    message =
      case Enum.random(1..4) do
        1 -> "........"
        2 -> "Hmmm.........."
        3 -> "Hmmm... you shouldn't be here....."
        4 -> "You're trespassing on forbidden grounds......."
      end

    ctx |> mes(message) |> close()
  end
end
