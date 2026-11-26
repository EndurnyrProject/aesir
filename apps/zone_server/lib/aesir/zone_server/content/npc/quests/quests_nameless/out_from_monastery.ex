defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OutFromMonastery do
  @moduledoc """
  Moves eligible players out of the monastery.

  ## Behavior

  - Advances the monastery quest when the player leaves.
  - Disables the trigger on initialization and otherwise on touch.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nameless_in",
        x: 12,
        y: 37,
        dir: 0,
        sprite: 45,
        name: "Out_from_Monastery",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 19 do
      ctx
      |> set_char_var(:aru_monas, 20)
      |> warp("nameless_n", 168, 252)
    else
      disablenpc(ctx, "Out_from_Monastery")
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnInit", ctx), do: disablenpc(ctx, "Out_from_Monastery")

  @impl true
  def on_talk(ctx), do: ctx
end
