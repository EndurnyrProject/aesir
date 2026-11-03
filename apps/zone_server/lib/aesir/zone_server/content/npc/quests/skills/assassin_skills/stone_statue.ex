defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AssassinSkills.StoneStatue do
  @moduledoc """
  Stone statue in the Sphinx that hides Esmille's Ruby in the Sonic Acceleration quest.

  ## Behavior

  - On the statue step, touching it offers to dig beneath its feet.
  - Two times in three a gas puts the player to sleep; otherwise they receive a Ruby and
    advance the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - L0ne_W0lf
    - 2Spiritual Kid (bug report)

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :ASSN_SK, 0) == 3, do: inspect_statue(ctx), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp inspect_statue(ctx) do
    {ctx, choice} =
      ctx
      |> specialeffect(:cone)
      |> mes("^3355FFThis ancient stone statue")
      |> mes("is covered with cracks and")
      |> mes("looks close to falling apart.")
      |> mes("The glimmer of a shining object")
      |> mes("peers out from beneath one of")
      |> mes("the feet. The ground appears")
      |> mes("soft enough to dig through...^000000")
      |> specialeffect(:cone)
      |> next()
      |> select(["Dig to retrieve the shining object", "Ignore it"])

    if choice == 1, do: dig(ctx), else: close(ctx)
  end

  defp dig(ctx) do
    ctx = ctx |> mes("^3355FFAs your fingers dig into") |> mes("the soft ground, it emits^000000")

    if Enum.random(1..3) != 3 do
      ctx
      |> mes("^3355FFa yellow gas that clouds")
      |> mes("your senses and briefly")
      |> mes("knocks you unconscious.^000000")
      |> sc_start(:sc_sleep, 30000, 0)
      |> close()
    else
      ctx
      |> mes("^3355FFa yellow gas. However, you")
      |> mes("hold your breath in and expel")
      |> mes("all gas in your lungs in time")
      |> mes("to escape its effects. You've")
      |> mes("retrieved a Ruby for Esmille.^000000")
      |> set_char_var(:ASSN_SK, 5)
      |> give_item(723, 1)
      |> close()
    end
  end
end
