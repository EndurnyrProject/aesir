defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Examiner1414 do
  @moduledoc """
  Tracks and scores participants in the rhythm exam.

  ## Behavior

  - Records hits and assigns the result when a participant leaves.
  - Resets and disables the examiner after the test.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in01",
        x: 14,
        y: 14,
        dir: 0,
        sprite: -1,
        name: "Examiner",
        scope: :shared,
        unique_name: "Examiner#sd",
        trigger: {6, 6}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disable(ctx)
  def on_event("OnTouch_", ctx), do: finish_exam(ctx)
  def on_event("OnUp", ctx), do: set_npc_var(ctx, "s_check", get_npc_var(ctx, "s_check", 0) + 1)
  def on_event("OnDisable", ctx), do: ctx |> set_npc_var("s_check", 0) |> disable()

  @impl true
  def on_talk(ctx), do: disable(ctx)

  defp disable(ctx), do: disablenpc(ctx, "Examiner#sd")

  defp finish_exam(ctx) do
    score = get_npc_var(ctx, "s_check", 0)

    ctx =
      cond do
        score < 30 and get_char_var(ctx, :sign_q, 0) == 30 -> set_char_var(ctx, :sign_q, 32)
        score < 34 and get_char_var(ctx, :sign_q, 0) == 30 -> set_char_var(ctx, :sign_q, 33)
        score == 34 and get_char_var(ctx, :sign_q, 0) == 30 -> set_char_var(ctx, :sign_q, 34)
        true -> ctx
      end

    ctx |> warp("cmd_in01", 29, 33) |> donpcevent("Examiner#sd::OnDisable")
  end
end
