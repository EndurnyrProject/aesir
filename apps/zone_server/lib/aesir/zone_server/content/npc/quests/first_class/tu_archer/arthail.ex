defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.Arthail do
  @moduledoc """
  Arthail of the Wind, a shy Bard in Prontera whom Master Kavaruk sends Archer trainees to find.

  ## Behavior

  - At Archer errand step 2, hearing about Kavaruk makes him ask the player to gather news
    at the central fountain, advancing the errand step to 3.
  - At step 4, after hearing the news he falls asleep while screams ring out from Prontera
    Castle, advancing the errand step to 5.
  - At step 8, after the palace visit he asks the player to report back to Kavaruk,
    advancing the errand step to 9.
  - Otherwise he refuses to sing, repeats his request, or sleeps.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prontera", x: 126, y: 335, dir: 5, sprite: 51, name: "Arthail", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Arthail]")
    step = get_char_var(ctx, :tu_archer02, 0)

    ctx =
      cond do
        step < 3 ->
          introduction(ctx)

        step == 3 ->
          ctx
          |> mes("I'm ashamed to ask,")
          |> mes("but would you go the fountain in Prontera's central plaza and see")
          |> mes("if there's any news?")

        step == 4 ->
          ctx
          |> discuss_the_emperium()
          |> hear_the_screams()

        step > 4 and step < 7 ->
          mes(ctx, "^333333Zzzzz...^000000")

        step == 8 ->
          send_back_to_kavaruk(ctx)

        true ->
          ctx
          |> mes("...")
          |> mes("......")
      end

    close(ctx)
  end

  defp introduction(ctx) do
    ctx =
      ctx
      |> mes("I am the Bard")
      |> mes("who sings only for")
      |> mes("himself. The gentle")
      |> mes("breeze is the only")
      |> mes("audience I have.")
      |> next()
      |> mes("[Arthail]")
      |> mes("I am Arthail")
      |> mes("of the Wind.")
      |> mes("I sing for no man,")
      |> mes("so you had best be on")
      |> mes("your way. I'm sorry, but")
      |> mes("I have no songs to share.")

    if get_char_var(ctx, :tu_archer02, 0) == 2, do: ask_for_news(ctx), else: ctx
  end

  defp ask_for_news(ctx) do
    {ctx, _} = ctx |> next() |> select(["Master Kavaruk told me to find you!"])

    ctx
    |> mes("[Arthail]")
    |> mes("Really now?")
    |> mes("I suppose it")
    |> mes("can't be helped.")
    |> mes("I really should")
    |> mes("have contacted him.")
    |> next()
    |> mes("[Arthail]")
    |> mes(
      "However, I'm very tired from the long trip. I'm exhausted from the crowding of this city and the hundreds of talking people."
    )
    |> mes("I can't handle it all...")
    |> next()
    |> mes("[Arthail]")
    |> mes(
      "Why can't I be like everyone else? It seems that as I approach people, my heart retreats further away from them. I wonder why that is?"
    )
    |> next()
    |> mes("[Arthail]")
    |> mes("I became a Bard to try to fix this social complex of mine, but to")
    |> mes(
      "no avail. Still, I feel much more at ease when I sing. Ah, but I've said too much already."
    )
    |> next()
    |> mes("[Arthail]")
    |> mes("Master Kavaruk")
    |> mes("asked you to help")
    |> mes("me? Well then, I have")
    |> mes("a favor to ask of you.")
    |> next()
    |> mes("[Arthail]")
    |> mes("Here in the capital of the")
    |> mes(
      "Rune-Midgarts Kingdom, there's supposed to be a fountain in the central plaza. Everyone seems to stop and chat over there."
    )
    |> next()
    |> mes("[Arthail]")
    |> mes(
      "However, I have a fear of other people and I can't bring myself to go near the crowds of people there. It's embarassing for me to admit this as a Bard..."
    )
    |> next()
    |> mes("[Arthail]")
    |> mes(
      "Would you please go and see if there's any news being spread around in that area for me?"
    )
    |> set_char_var(:tu_archer02, 3)
  end

  defp discuss_the_emperium(ctx) do
    ctx
    |> mes("I see...")
    |> mes("Nothing much.")
    |> mes("Another person")
    |> mes("found an Emperium")
    |> mes("and is starting a")
    |> mes("brand new guild...")
    |> next()
    |> mes("[Arthail]")
    |> mes("^3131FFEmperium^000000...")
    |> mes(
      "There are a lot of ambitious people in Morocc that want one of those. Even in my hometown of Payon,"
    )
    |> mes("there are people clamoring to obtain one...")
    |> next()
    |> mes("[Arthail]")
    |> mes("Supposedly, having an Emperium")
    |> mes("will give you the power to change the world. People are bound to be attracted to it.")
    |> next()
    |> mes("[Arthail]")
    |> mes("Hmm...?")
    |> mes("I sense something")
    |> mes("dark and ominous...")
    |> mes("I wonder what it could be?")
    |> emotion(:scratch)
    |> next()
    |> mes("[Arthail]")
    |> mes("I'm probably just stressed and exhausted. I'll feel better once")
    |> mes("I get some rest. Would you like to join me and listen to the flowing water?")
    |> next()
    |> mes("[Arthail]")
    |> mes(
      "It's not the greatest feeling if you stay here for too long, but the sound of this water reminds me of home. Did you see the lake by the Icarus Guild? These waters remind me of that place."
    )
    |> next()
    |> mes("[Arthail]")
    |> mes("^333333*Yawn...*^000000")
    |> mes("I haven't talked")
    |> mes("like this in so long.")
    |> mes("I'm so tired, I think")
    |> mes("I'll rest just a little...")
    |> next()
    |> mes("[Arthail]")
    |> mes("..........")
    |> next()
    |> mes("^3355FFArthail of the Wind")
    |> mes("has fallen fast asleep.^000000")
    |> next()
  end

  defp hear_the_screams(ctx) do
    ctx
    |> player_line()
    |> mes("Ah...")
    |> mes("So peaceful~")
    |> next()
    |> mes(
      "^3355FFThe rhythm of the lapping waters gently eases you into a state of perfect relaxation. The cold, crisp water would feel so refreshing if you dipped your feet into it...^000000"
    )
    |> next()
    |> mes("[???]")
    |> mes("...")
    |> soundeffectall("se_littlewaves02.wav", 0)
    |> next()
    |> player_line()
    |> mes("Huh?")
    |> mes("What was")
    |> mes("that noise?")
    |> next()
    |> mes("[????]")
    |> mes("AAAAAAAAAAAAAAAHHHHHHHHHHH!!!!!")
    |> emotion(:huk)
    |> soundeffectall("se_scream_w01.wav", 0)
    |> next()
    |> player_line()
    |> mes("What the--?!")
    |> mes("That sounds like")
    |> mes("screams coming from")
    |> mes("inside Prontera Castle!")
    |> next()
    |> mes("^3355FFYou try to wake Arthail")
    |> mes("but he's deeply asleep")
    |> mes("and won't budge at all.^000000")
    |> next()
    |> player_line()
    |> mes("I can't help it then.")
    |> mes("I'd better go check")
    |> mes("this out on my own.")
    |> set_char_var(:tu_archer02, 5)
  end

  defp send_back_to_kavaruk(ctx) do
    ctx
    |> mes("Where did you go?")
    |> mes("I thought you might have been kidnapped since you weren't")
    |> mes("here when I woke up.")
    |> next()
    |> mes("[Arthail]")
    |> mes("So everyone said nothing")
    |> mes("happened when you asked")
    |> mes("about the shrieks you heard?")
    |> mes("That's really peculiar...")
    |> next()
    |> mes("[Arthail]")
    |> mes(
      "Even the Emperium you mentioned earlier. I thought it was supposed to be a rare item, but why is it so easy for so many people to get"
    )
    |> mes("one? It's very strange...")
    |> next()
    |> mes("[Arthail]")
    |> mes("Huh. I better investigate this")
    |> mes(
      "a little more, so I'll stay here to gather more information. For now, you should head back to Payon and let Master Kavaruk know that I'm doing alright."
    )
    |> next()
    |> mes("[Arthail]")
    |> mes("And one day...")
    |> mes("I guess I'll finally")
    |> mes("have a song that")
    |> mes("I can share with you.")
    |> set_char_var(:tu_archer02, 9)
  end

  defp player_line(ctx), do: mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
end
