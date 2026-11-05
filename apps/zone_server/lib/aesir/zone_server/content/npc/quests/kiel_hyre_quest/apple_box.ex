defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.AppleBox do
  @moduledoc """
  This box of apples provokes a warning from the player’s inner voice.

  ## Behavior

  - Allows examining or leaving the box, but never taking it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_vila",
        x: 30,
        y: 184,
        dir: 0,
        sprite: 111,
        name: "Apple Box",
        scope: :shared,
        unique_name: "Apple Box#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou find a box filled with")
      |> mes("ripe, delicious apples.^000000")
      |> next()
      |> select(["Take the box", "Leave it"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFNo...! Wait!")
        |> mes("Something's wrong!")
        |> mes("Whatever you do,")
        |> mes("don't take this box!^000000")
        |> next()
        |> mes("^3355FFAnd so, your inner")
        |> mes("voice, your Jungian")
        |> mes("shadow if you will,")
        |> mes("prevented you from")
        |> mes("taking the box.^000000")
        |> close()

      2 ->
        ctx
        |> mes("^3355FFSomething is wrong")
        |> mes("with this box of apples.^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
