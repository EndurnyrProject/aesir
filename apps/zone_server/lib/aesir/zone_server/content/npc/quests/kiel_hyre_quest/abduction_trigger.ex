defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.AbductionTrigger do
  @moduledoc """
  The mansion exit ambush knocks the adventurer unconscious during the Kiel Hyre quest.

  ## Behavior

  - At the required quest stage, closes the dialogue, removes nearly all HP, and transfers the adventurer into the mansion.

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
        map: "lighthalzen",
        x: 188,
        y: 200,
        dir: 0,
        sprite: -1,
        name: "Abduction_trigger",
        scope: :shared,
        trigger: {3, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) == 50 do
      ctx
      |> mes("^3355FFAs you walked out of")
      |> mes("the mansion, something")
      |> mes("smashed the top of your")
      |> mes("head, and you instantly")
      |> mes("lose consciousness...")
      |> close()
      |> percent_heal(hp: -99, sp: 0)
      |> warp("kh_mansion", 30, 75)
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch", ctx)
end
