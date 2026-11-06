defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AssassinSkills.Npc do
  @moduledoc """
  Hidden flooded-crypt spot where Assassins search for Esmille's Aquamarine.

  ## Behavior

  - On the crypt step of the Sonic Acceleration quest, touching the water offers to pick up a
    glimmering object.
  - Two times in three the player is frozen; otherwise they receive an Aquamarine and advance
    the quest.

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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_pryd04",
        x: 85,
        y: 96,
        dir: 0,
        sprite: -1,
        name: "¡¡",
        scope: :shared,
        unique_name: "¡¡#crypt",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :ASSN_SK, 0) == 4, do: search_water(ctx), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)

  defp search_water(ctx) do
    {ctx, choice} =
      ctx
      |> specialeffect(:cone)
      |> mes("^3355FFThere's something")
      |> mes("glimmering beneath")
      |> mes("the surface of the water...^000000")
      |> next()
      |> select(["Pick it up", "Ignore it"])

    if choice == 1, do: pick_up_jewel(ctx), else: close(ctx)
  end

  defp pick_up_jewel(ctx) do
    ctx =
      ctx
      |> mes("^3355FFAs soon as you dip your")
      |> mes("hand into the water, the")
      |> mes("water's freezing chill shoots")
      |> mes("up through your arm. You ")
      |> mes("better hurry before you freeze!^000000")
      |> next()

    if Enum.random(1..3) != 3 do
      ctx
      |> mes("^3355FFIt's too late!")
      |> mes("Your body has just")
      |> mes("been frozen solid.^000000")
      |> sc_start(:sc_freeze, 10000, 0)
      |> close()
    else
      ctx
      |> mes("^3355FFYou quickly pick up")
      |> mes("the glimmering object")
      |> mes("before the water can")
      |> mes("freeze you. You obtained")
      |> mes("an Aquamarine for Esmille.^000000")
      |> set_char_var(:ASSN_SK, 5)
      |> give_item(720, 1)
      |> close()
    end
  end
end
