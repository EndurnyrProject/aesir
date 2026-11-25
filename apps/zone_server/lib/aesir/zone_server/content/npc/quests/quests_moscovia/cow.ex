defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Cow do
  @moduledoc """
  Baba Yaga's runaway cow challenges the player to recall a spell.

  ## Behavior

  - The cow flees between locations unless the player casts the correct spell.
  - A successful spell advances the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun02",
        x: 257,
        y: 193,
        dir: 0,
        sprite: 889,
        name: "Cow",
        scope: :shared,
        unique_name: "Cow#rus33",
        trigger: {3, 3}
      },
      %{
        map: "mosk_dun02",
        x: 146,
        y: 247,
        dir: 4,
        sprite: 889,
        name: "Cow",
        scope: :shared,
        unique_name: "Cow#rus34",
        trigger: {3, 3}
      },
      %{
        map: "mosk_dun02",
        x: 102,
        y: 107,
        dir: 4,
        sprite: 889,
        name: "Cow",
        scope: :shared,
        unique_name: "Cow#rus35",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx), do: ctx

  def ev_ontouch(ctx) do
    ctx = ctx |> mes("[Cow]") |> mes("Moo...")

    case get_char_var(ctx, :rhea_rus_main, 0) do
      11 ->
        confront_cow(ctx)

      41 ->
        ctx
        |> next()
        |> mes("- The cow is tied around its neck and eats grass comfortably -")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I must return to Baba Yaga...")
        |> close()

      _ ->
        close(ctx)
    end
  end

  defp confront_cow(ctx) do
    ctx =
      ctx
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hah, t, that is Baba Yaga's cow?!")
      |> mes("Y, you...")
      |> next()
      |> mes("- You approach to the cow carefully and hold its nape -")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You! Go home now!")
      |> emotion(:huk)
      |> next()
      |> mes("- The cow seems surprised, jumps and tries to attack you !! -")
      |> next()

    ctx = set_local(ctx, :npc_num, Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 2), 4)))

    other_cows =
      case get_local(ctx, :npc_num, 0) do
        3 -> [4, 5]
        4 -> [3, 5]
        _ -> [3, 4]
      end

    ctx = set_local(ctx, :other_npc, other_cows)

    if Enum.random(1..4) == 3 do
      cast_spell(ctx)
    else
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Akkkk?! Eh!? The s-spell...")
      |> next()
      |> mes(
        "- You hesitate, the cow, seems to gibe at you, passes by you and runs to bushes !! -"
      )
      |> disablenpc()
      |> move_cow()
      |> close()
    end
  end

  defp cast_spell(ctx) do
    {ctx, spell} =
      ctx
      |> mes("- You almost get hit and dodge its attack and cast the spell !! -")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", spell)

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(Rathena.concat(Rathena.concat("", get_local(ctx, :"input$", "")), " !!!"))

    if get_local(ctx, :"input$", "") == "Good feed is orange-flavored" do
      ctx =
        ctx
        |> specialeffect(:teleportation2)
        |> next()
        |> mes(
          "- You cast the spell in a hurry and the cow is surronded by the light and disappears !! -"
        )
        |> disablenpc()
        |> enablenpc(Rathena.concat("Cow#rus3", Enum.at(get_local(ctx, :other_npc, []), 0, 0)))
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What a surprise. The cow is bad like its owner.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ok, then. Let's get back to Baba Yaga...")
      |> set_char_var(:rhea_rus_main, 41)
      |> close()
    else
      ctx
      |> next()
      |> mes("[Cow]")
      |> mes("...Moo...")
      |> emotion(:think)
      |> next()
      |> mes("- The cow, seems to gibe at you, looks at you quickly and runs to bushes !! -")
      |> disablenpc()
      |> move_cow()
      |> close()
    end
  end

  defp move_cow(ctx) do
    index = if Rathena.truthy?(:rand.uniform(2) - 1), do: 0, else: 1
    enablenpc(ctx, Rathena.concat("Cow#rus3", Enum.at(get_local(ctx, :other_npc, []), index, 0)))
  end
end
