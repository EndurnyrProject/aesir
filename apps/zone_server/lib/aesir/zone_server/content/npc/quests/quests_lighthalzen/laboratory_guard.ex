defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LaboratoryGuard do
  @moduledoc """
  A laboratory guard questions the player's delivery inquiry.

  ## Behavior

  - Responds to the investigation and advances the delivery job.

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
        map: "einbroch",
        x: 55,
        y: 52,
        dir: 3,
        sprite: 852,
        name: "Laboratory Guard",
        scope: :shared,
        unique_name: "Laboratory Guard#reken"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :lhz_rekenber, 0) == 3 do
      ask_business(ctx)
    else
      ctx
      |> mes("[Laboratory Guard]")
      |> mes("This area is restricted")
      |> mes("to the public. Unless you")
      |> mes("have some kind of special")
      |> mes("authorization, I'm going")
      |> mes("to have to ask you to leave.")
      |> close()
    end
  end

  defp ask_business(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Laboratory Guard]")
      |> mes("Hold it! This is")
      |> mes("a restricted area to")
      |> mes("the public! Unless you")
      |> mes("have some special business,")
      |> mes("you'll have to leave right now.")
      |> next()
      |> select(["Actually, I do have business here.", "Whoa, I'm leaving!"])

    case choice do
      1 -> ask_contact(ctx)
      2 -> leave(ctx, "Whoa, I'm leaving!")
      _ -> ctx
    end
  end

  defp ask_contact(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Laboratory Guard]")
      |> mes("Yes? State the nature")
      |> mes("of your business here,")
      |> mes("as well as any person that")
      |> mes("you wish to contact inside")
      |> mes("of this laboratory facility.")
      |> next()
      |> select(["I need to see Mr. Garins...", "I'll... come back later."])

    case choice do
      1 -> inquire_about_garins(ctx)
      2 -> leave(ctx, "I'll... come back later.")
      _ -> ctx
    end
  end

  defp inquire_about_garins(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I need to see Mr. Garins")
    |> mes("and confirm that he received")
    |> mes("a package that was sent to him.")
    |> next()
    |> mes("[Laboratory Guard]")
    |> mes("Garins, eh?")
    |> mes("Alright, let me check")
    |> mes("the employee list. Hmm...")
    |> mes("Garins... Garins... Eh?")
    |> mes("He's not here. Maybe you")
    |> mes("came to the wrong place?")
    |> next()
    |> mes("[Laboratory Guard]")
    |> mes("Sorry, but it looks like")
    |> mes("you've wasted your time.")
    |> mes("We don't have a Garins")
    |> mes("working here. Anyway,")
    |> mes("I still can't allow you to")
    |> mes("enter the laboratory.")
    |> set_char_var(:lhz_rekenber, 4)
    |> close()
  end

  defp leave(ctx, reply) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(reply)
    |> mes("(^333333I better speak to Kazien")
    |> mes("and let him know I'm having")
    |> mes("trouble getting past this")
    |> mes("guard. Otherwise, I might")
    |> mes("never finish this job!^000000)")
    |> set_char_var(:lhz_rekenber, 5)
    |> changequest(12_008, 12_010)
    |> close()
  end
end
