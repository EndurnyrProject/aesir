defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.FirePot do
  @moduledoc """
  The fire pot conceals Mikhail during the Swan quest.

  ## Behavior

  - Investigate the pot and help Mikhail repair the Matrushka.

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
        map: "mosk_in",
        x: 205,
        y: 268,
        dir: 3,
        sprite: 111,
        name: "Fire pot",
        scope: :shared,
        unique_name: "Fire pot#mos"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :mos_swan, 0)

    cond do
      not Rathena.truthy?(stage) ->
        ordinary_pot(ctx)

      stage == 1 ->
        ctx
        |> mes("- It's a fire pot that is used when Gallina bakes hotcakes.")
        |> mes("It seems that this has not been used for a long time.")
        |> mes("I think I should ask his family where he might have fun off to -")
        |> set_char_var(:mos_swan, 2)
        |> close()

      stage < 11 ->
        old_pot(ctx) |> close()

      stage == 11 ->
        investigate(ctx)

      stage == 12 ->
        ctx
        |> mes("- Ok, what I have to do first is ask Mr. Victor what I need for the paste. -")
        |> close()

      stage == 24 ->
        deliver_paste(ctx)

      true ->
        ordinary_pot(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ordinary_pot(ctx) do
    ctx |> mes("- It's a fire pot to heat the room or bake something -") |> close()
  end

  defp old_pot(ctx) do
    ctx
    |> mes("- It's a fire pot that is used when Gallina bakes hotcakes.")
    |> mes("It seems that it was used a long time ago. -")
  end

  defp investigate(ctx) do
    {ctx, choice} = ctx |> old_pot() |> next() |> select(["Check other things", "Look it over"])

    if choice == 1 do
      ctx |> mes("- You decide to check out other things -") |> close()
    else
      inspect_pot(ctx)
    end
  end

  defp inspect_pot(ctx) do
    {ctx, choice} =
      ctx
      |> mes("- You come near the pot to look it over. -")
      |> next()
      |> mes(" .............. ")
      |> mes(" .............. ")
      |> mes(" .............. ")
      |> mes(" .............. ")
      |> next()
      |> mes(" .............. ")
      |> mes(" .............. ")
      |> mes(" .............. ")
      |> mes(" .............. ")
      |> mes(" .............. ")
      |> next()
      |> mes(
        "- As you look it over very carefully, you find some pieces of bread on the floor around the fire pot! -"
      )
      |> next()
      |> select([
        "Mikhail is in the fire pot.",
        "Mikhail is around the fire pot.",
        "There's nothing between pieces of bread and Mikhail."
      ])

    case choice do
      1 -> find_mikhail(ctx)
      2 -> ctx |> mes("- I guess he's near the fire pot. Where can I find him? -") |> close()
      3 -> ctx |> mes("- I guess pieces of bread have nothing to do with Mikhail. -") |> close()
      _ -> ctx
    end
  end

  defp find_mikhail(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I finally found him.")
    |> next()
    |> mes("- You put your arm into the hole of the fire pot. -")
    |> next()
    |> mes("- Something makes a rustling sound. -")
    |> next()
    |> mes("- You call Mikhail with a low voice. -")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Mik-ha-il-.")
    |> next()
    |> mes("- .......................... -")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Mikhail.")
    |> mes("I know you're there, please come out.")
    |> next()
    |> mes("- .......................... -")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Your mom and sister are worried about you.")
    |> next()
    |> mes("[???]")
    |> mes(".......hey.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("?????")
    |> next()
    |> mes("[Mikhail]")
    |> mes(".......No, I can't............")
    |> mes("I'll.... be punished........")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("No, you won't, Mikhail.")
    |> mes("Your mom is worried about you so much.")
    |> mes("Your sister, too.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You broke your mom's Matrushka by mistake, didn't you?")
    |> mes("I'll tell her about your mistake. Please come out.")
    |> next()
    |> mes("[Mikhail]")
    |> mes("Oh.. ma.. matrushka..")
    |> mes("I didn't break..it.. it..wasn't.. just me!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("And?")
    |> next()
    |> mes("[Mikhail]")
    |> mes("Anna pushed me and bumped me......")
    |> mes("But she told Mom that it was just me who broke it....")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, dear! You and Anna did that but she put all the blame on you?")
    |> next()
    |> mes("[Mikhail]")
    |> mes("Yes.....")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You should come out and tell your mom the truth! Let's go Mikhail.")
    |> next()
    |> mes("[Mikhail]")
    |> mes("No! No, I can't!!")
    |> next()
    |> mes("- A small-white hand comes out of the fire pot and grabs your ankle -")
    |> next()
    |> mes("[Mikhail]")
    |> mes("No...I'm afraid that Mom will punish me...")
    |> mes("Because Grandma's Matrushka is broken......")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, my. Please don't cry little boy.")
    |> mes(
      "There's no way. I'll get a paste to bond all the pieces together. And then you can bring it back to your mom and apologize to her."
    )
    |> next()
    |> mes("[Mikhail]")
    |> mes("Can you... get... a paste?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You don't believe me?")
    |> mes("Ok, stay here. I'll be right back with the paste.")
    |> next()
    |> mes("- I need to know what's required for the paste.")
    |> mes("I'll ask that guy ^3131FFMr. Victor^000000 about them. -")
    |> set_char_var(:mos_swan, 12)
    |> changequest(18064, 18065)
    |> close()
  end

  defp deliver_paste(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hey, Mikhail. I've got the paste!.")
    |> next()
    |> mes("[Mikhail]")
    |> mes("......Really? are you serious?")
    |> next()
    |> donpcevent("Mikhail#mos::OnEnable")
    |> mes("- You hand over the paste from Victor to Mikhail. -")
    |> next()
    |> mes("[Mikhail]")
    |> mes("Wow! Great!")
    |> next()
    |> mes(
      "- He begins working on the broken Matrushka as if he was piecing together a puzzle. -"
    )
    |> next()
    |> mes("[Mikhail]")
    |> mes("I've done it!!!!!!!")
    |> mes("Thank you so much!!!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("You're welcome, haha.")
    |> mes("Anyway, can you promise me one thing?")
    |> next()
    |> mes("[Mikhail]")
    |> mes("What?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(
      "Bring back the Matrushka to your mother, and promise me that you will be a brave general in the future."
    )
    |> next()
    |> mes("[Mikhail]")
    |> mes(".............")
    |> next()
    |> mes("[Mikhail]")
    |> mes("OK, I will!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hoohoo, you're good boy.")
    |> next()
    |> mes("[Mikhail]")
    |> mes("Now I'm gonna give this back to Mom.")
    |> donpcevent("Mikhail#mos::OnInit")
    |> set_char_var(:mos_swan, 25)
    |> delitem(7764, 1)
    |> changequest(18068, 18069)
    |> close()
  end
end
