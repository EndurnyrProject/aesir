defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LiBother do
  @moduledoc """
  A mysterious spirit returns to haunt the player.

  ## Behavior

  - Advances the curse quest and awards experience based on level and mode.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 319,
        y: 321,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#li_bother",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx), do: encounter_spirit(ctx)

  @impl true
  def on_talk(ctx), do: encounter_spirit(ctx)

  defp encounter_spirit(ctx) do
    if get_char_var(ctx, :lhz_curse, 0) in [24, 25] do
      spirit_dialogue(ctx)
    else
      ctx
    end
  end

  defp spirit_dialogue(ctx) do
    ctx =
      ctx
      |> mes(".............")
      |> next()
      |> mes("*Shhhzzzzzzz!*")
      |> specialeffect2(:mappillar)
      |> next()
      |> mes("[????]")
      |> mes("...........")
      |> next()
      |> mes("[????]")
      |> mes("^FF0000...I'm sorry...")
      |> mes("......I appreciate")
      |> mes("that you.............^000000")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("H-huh?!")
      |> mes("What was that?")
      |> mes("That can't be the")
      |> mes("wind, I must be")
      |> mes("hearing things again...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wait. I thought I was")
      |> mes("rid of those thoughts")
      |> mes("or spirits, whatever was")
      |> mes("haunting me before. Maybe")
      |> mes("they still want me to do")
      |> mes("something for them. Hmmm...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I get the feeling that")
      |> mes("all of their suffering")
      |> mes("is tied to the ^FF0000Rekenber")
      |> mes("Corporation^000000 and that")
      |> mes("^FF0000Regenschirm Laboratory^000000.")
      |> set_char_var(:lhz_curse, 26)
      |> changequest(2093, 2094)

    ctx |> award_experience() |> close()
  end

  defp award_experience(ctx) do
    renewal = Rathena.truthy?(checkre(ctx, 3))
    level = base_level(ctx)

    {base_exp, job_exp} =
      cond do
        renewal and level < 70 -> {30_000, 30_000}
        renewal and level < 80 -> {40_000, 70_000}
        renewal and level < 90 -> {70_000, 90_000}
        renewal -> {90_000, 90_000}
        level < 70 -> {800_000, 300_000}
        level < 80 -> {1_000_000, 500_000}
        level < 90 -> {1_500_000, 800_000}
        true -> {2_000_000, 1_000_000}
      end

    getexp(ctx, base_exp, job_exp)
  end
end
