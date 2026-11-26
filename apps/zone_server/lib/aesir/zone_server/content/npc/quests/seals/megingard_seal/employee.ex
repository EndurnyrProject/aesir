defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.Employee do
  @moduledoc """
  The Morroc Inn employee who knows where Cuaque Donon hides and may give the Megingard Seal
  quest's hint about him.

  ## Behavior

  - Outside the Megingard seal phase she only welcomes guests and gossips about the Inn owner.
  - Once the player is looking for the squad and has no hint yet, she asks who they are looking
    for; naming Cuaque Donon early gets a denial, any other name gets a puzzled answer.
  - Later in the quest, naming Cuaque makes her threaten the player: depending on the answer
    and a random roll, she either knocks the player out (HP drained) or gives the hint and
    marks it as received.
  - After the hint, she greets the player as if nothing happened.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Answering "Wait, is he in hiding?" and being knocked out now ends the talk, like the other
    two knock-outs; the original lacked the `end;` there and fell through into the
    "Just curious?" dialog after the window had closed.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 146,
        y: 179,
        dir: 0,
        sprite: 66,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#megin1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if seal_phase_open?(ctx) do
      seal_talk(ctx)
    else
      ctx
      |> welcome()
      |> next()
      |> mes("[Inn Employee]")
      |> mes(
        "Oh, and I have a bit of a secret...! I hear the Inn's owner is planning some kind of shady business. It's some sort of major project, but don't let anyone know I told you!"
      )
      |> close()
    end
  end

  defp seal_phase_open?(ctx) do
    get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0)
  end

  defp seal_talk(ctx) do
    cond do
      get_char_var(ctx, :god_eremes, 0) > 17 and get_char_var(ctx, :god_megin_2, 0) < 1 ->
        ask_who(ctx)

      get_char_var(ctx, :god_megin_2, 0) > 0 ->
        ctx
        |> welcome()
        |> next()
        |> mes("^3355FFShe welcomed you")
        |> mes("very professionally,")
        |> mes("as if nothing")
        |> mes("had happened.^000000")
        |> close()

      true ->
        ctx |> welcome() |> close2()
    end
  end

  defp ask_who(ctx) do
    {ctx, answer} =
      ctx
      |> mes("^3355FFThe Inn Employee")
      |> mes("eyes you suspiciously.^000000")
      |> next()
      |> mes("[Inn Employee]")
      |> mes("Excuse me.")
      |> mes("How can I help you?")
      |> mes("Are you looking for")
      |> mes("someone...?")
      |> next()
      |> input(:string)

    ctx = set_temp_var(ctx, :"str$", answer)
    name = get_temp_var(ctx, :"str$", "")

    if name in ["Cuaque Donon", "Cuaque", "Donon"] do
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Do you happen to know a person named #{name} ...?")
      |> asked_about_cuaque(get_char_var(ctx, :god_eremes, 0))
    else
      ctx
      |> mes("[Inn Employee]")
      |> mes("What...?")
      |> mes("I don't know")
      |> mes("anyone named that.")
      |> mes("If that's even a name...")
      |> close2()
    end
  end

  defp asked_about_cuaque(ctx, 18) do
    ctx
    |> mes("[Inn Employee]")
    |> mes("I don't think")
    |> mes("I know that person.")
    |> mes("I guess that guy left")
    |> mes("before I started working")
    |> mes("here, maybe?")
    |> close()
  end

  defp asked_about_cuaque(ctx, _stage) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("^3355FFOnce you said that name, she immediately drew closer to you")
      |> mes("and began speaking in a low, threatening tone.^000000")
      |> next()
      |> mes("[Scary Inn Employee]")
      |> mes("Who the hell are you?")
      |> mes("If you try anything funny,")
      |> mes("I'll rip your heart out!")
      |> mes("Why are you so curious?!")
      |> mes("Are you one of them?!")
      |> next()
      |> select(["Rebarev Doug sent me!", "Wait, is he in hiding?", "Just... curious."])

    case choice do
      1 -> rebarev_doug_sent_me(ctx)
      2 -> is_he_hiding(ctx)
      3 -> just_curious(ctx)
      _ -> ctx
    end
  end

  defp rebarev_doug_sent_me(ctx) do
    ctx =
      ctx
      |> mes("[Ms. Scary Inn Employee]")
      |> mes("Rebarev Doug...?!")
      |> mes("That old coot must be afraid")
      |> mes("of the rumors we're spreading around. Is already deperate enough to send his men?!")
      |> next()
      |> mes("[Ms. Scary Inn Employee]")

    if Enum.random(1..10) > 3 do
      ctx
      |> mes("But...")
      |> mes("I'm not in the mood")
      |> mes("to guide you over to")
      |> mes("Cuaque Donon...")
      |> next()
      |> knock_out()
    else
      ctx
      |> mes("Hmm...")
      |> mes(
        "It might not be a bad idea to let someone like you talk to Cuaque Donon. You don't seem like the bad sort..."
      )
      |> next()
      |> mes("[Ms. Scary Inn Employee]")
      |> mes("But you only get a hint,")
      |> mes("and I'm saying it just once...")
      |> aragham_hint()
    end
  end

  defp is_he_hiding(ctx) do
    ctx =
      ctx
      |> mes("[Ms. Scary Inn Employee]")
      |> mes("Right.")
      |> mes("If you're here")
      |> mes("looking for him,")
      |> mes("you definitely know")
      |> mes("why he's hiding.")
      |> next()
      |> mes("[Ms. Scary Inn Employee]")

    if Enum.random(1..10) > 4 do
      ctx
      |> mes("How dare you...")
      |> mes("How dare you play")
      |> mes("dumb with me?!")
      |> next()
      |> knock_out()
    else
      ctx
      |> mes("Well, maybe not.")
      |> mes("Who knows what kind")
      |> mes("of friends Cuaque made")
      |> mes("when he was a Crusader.")
      |> mes("Alright, but listen...")
      |> next()
      |> mes("[Ms. Scary Inn Employee]")
      |> mes("I'm only giving")
      |> mes("you this hint once...")
      |> aragham_hint()
    end
  end

  defp just_curious(ctx) do
    ctx =
      ctx
      |> mes("[Ms. Scary Inn Employee]")
      |> mes("Just curious?")
      |> mes("Huh. You've got a lot of nerve, don't you? I'm sorry to tell you this but...")
      |> next()
      |> mes("[Ms. Scary Inn Employee]")

    if Enum.random(1..10) > 3 do
      ctx
      |> mes("I'm not in the mood")
      |> mes("to guide you over to")
      |> mes("Cuaque Donon...")
      |> mes("Heh heh heh...")
      |> next()
      |> knock_out()
    else
      ctx
      |> mes("I can't really tell")
      |> mes("you exactly where he")
      |> mes("is. The most I can do")
      |> mes("is give you a small hint.")
      |> mes("Listen carefully now...")
      |> mes("I'll only say it once.")
      |> next()
      |> mes("[Ms. Scary Inn Employee]")
      |> mes("^0000FFAragham never")
      |> mes("hoarded upgrade items.^000000")
      |> mes("Now, don't forget!")
      |> set_char_var(:god_megin_2, 1)
      |> close()
    end
  end

  defp knock_out(ctx) do
    ctx
    |> mes("^3355FFThe Inn Employee")
    |> mes("knocks you out~^000000")
    |> close2()
    |> percent_heal(hp: -100, sp: 0)
  end

  defp aragham_hint(ctx) do
    ctx
    |> mes("^0000FFAragham never hoarded")
    |> mes("upgrade items.^000000")
    |> set_char_var(:god_megin_2, 1)
    |> close()
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Inn Employee]")
    |> mes("Welcome to the Inn.")
    |> mes("When you move to the entrance, you can also enter a PvP zone though a PvP doorman.")
    |> next()
    |> mes("[Inn Employee]")
    |> mes(
      "Usually, you can visit inns in big towns. If you want to take a rest or compete with others, an Inn is the place to go."
    )
  end
end
