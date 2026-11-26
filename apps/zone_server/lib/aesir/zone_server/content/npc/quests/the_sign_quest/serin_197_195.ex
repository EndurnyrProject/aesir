defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Serin197195 do
  @moduledoc """
  Confronts the adventurer as Serin attempts to summon Dark Lord.

  ## Behavior

  - Offers a choice between stopping Serin and letting her proceed.
  - Starts the battle, handles retries and sends the adventurer away afterward.

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
        map: "que_sign01",
        x: 197,
        y: 195,
        dir: 4,
        sprite: 90,
        name: "Serin",
        scope: :shared,
        unique_name: "Serin#witch"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    case get_char_var(ctx, :sign_q, 0) do
      stage when stage < 124 ->
        ctx |> mes("[Serin]") |> mes("...") |> mes("......") |> emotion(:think) |> close()

      124 ->
        confront(ctx)

      125 ->
        battle_intro(ctx)

      126 ->
        farewell(ctx)

      127 ->
        return_to_niflheim(ctx)

      198 ->
        retry(ctx)

      200 ->
        send_to_midgard(ctx)

      _ ->
        ctx |> mes("[Serin]") |> mes(".........") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp confront(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("You're finally here.")
      |> mes("That witch has been watching")
      |> mes("my every move, so she probably")
      |> mes("knows what I'm up to by now...")
      |> next()
      |> select(["Why are you doing this..."])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("You don't understand")
      |> mes("the horrific experience")
      |> mes("of being bound to Niflheim.")
      |> mes("I'm sick of breathing death")
      |> mes("and feeding on despair.")
      |> mes("I want to live again!")
      |> next()
      |> select(["Is that why you want Dark Lord...?"])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("Unfortunately, the symbol")
      |> mes("which Lady Hell gave you is")
      |> mes("limited to a one time use. Its")
      |> mes("power wasn't enough to bring me")
      |> mes("back, so summoning Dark Lord is")
      |> mes("my last chance.")
      |> next()
      |> select(["But if Dark Lord comes to Midgard..."])

    ctx =
      ctx
      |> mes("[Serin]")
      |> mes("Oh, I'm pretty sure of")
      |> mes("what will happen if Dark Lord")
      |> mes(
        "enters the realm of the living. He'll destroy Midgard and bring death to thousands and thousands of people."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("So if I came back to life")
      |> mes("and everyone else were dead,")
      |> mes("However, by summoning Dark")
      |> mes(
        "Lord, you might be thinking it'd be pretty pointless for me to come back. But I don't care."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("The living don't appreciate")
      |> mes("what they have, so they ought")
      |> mes(
        "to be punished. They can all go to Niflheim while I enjoy the warmth of the sun and the fresh outside air. Everyone should die..."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("Maybe you might not")
      |> mes("pity my situation since you've")
      |> mes("never been bound to Niflheim,")
      |> mes("but I'm begging you. Don't get")

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("in my way, ", char_name(ctx, 0)), "."))
      |> next()
      |> select(["I can't let you do this!", "Okay, have it your way."])

    case choice do
      1 ->
        ctx |> set_char_var(:sign_q, 125) |> close()

      2 ->
        {ctx, confirmation} =
          ctx
          |> mes("[Serin]")
          |> mes("Are you really willing")
          |> mes("to throw so much away for")
          |> mes("my sake? You do understand")
          |> mes("that you'll be failing the ordeals set before you by the gods...")
          |> next()
          |> select(["I changed my mind for Midgard.", "I do, and it's alright..."])

        case confirmation do
          1 ->
            ctx |> set_char_var(:sign_q, 125) |> close()

          2 ->
            ctx =
              ctx
              |> mes("[Serin]")
              |> mes("The least I can")
              |> mes("do is send you back")
              |> mes("to Midgard and")
              |> mes("ask the Dark Lord to spare")
              |> mes("you. Thank you so much...")
              |> set_char_var(:sign_q, 200)

            ctx
            |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 20_000, else: 200_000), 0)
            |> set_server_temp_var("sign_w1", 0)
            |> close2()
            |> warp("umbala", 132, 203)

          _ ->
            ctx
        end

      _ ->
        ctx
    end
  end

  defp battle_intro(ctx) do
    has_ring? = count_item(ctx, 2643) == 1

    ctx =
      ctx
      |> mes("[Serin]")
      |> mes("If you think that")
      |> mes("I can't summon Dark Lord")
      |> mes("without the symbol, then you're")
      |> mes("mistaken. I've been collecting")
      |> mes("the power of despair!")
      |> next()

    ctx =
      if has_ring? do
        ctx
        |> mes("[Serin]")
        |> mes("Do you remember what")
        |> mes("happened to the dead that you")
        |> mes(
          "helped on my behalf? Even if they seemed to have found shelter at first, they cannot escape my"
        )
        |> mes("deep hollow of despair...")
        |> next()
        |> mes("[Serin]")
        |> mes("And that poor little girl,")
        |> mes("Alakina Anne? She still")
        |> mes("hasn't realized that she's dead!")
        |> next()
        |> mes("[Serin]")
        |> mes("You gave her hope,")
        |> mes("but ultimately, you can't")
        |> mes("keep your promise to bring her home. Oh, her disappointment")
        |> mes("must be so crushing...")
        |> next()
        |> mes("[Serin]")
        |> mes("Yes...")
        |> mes("By trying to help,")
        |> mes("you gave them nothing")
        |> mes("but pain, just as I planned.")
        |> mes("Now I have enough despair")
        |> mes("to summon Dark Lord!")
        |> next()
      else
        ctx
        |> mes("[Serin]")
        |> mes("What most adventurers")
        |> mes("don't know is that many of the")
        |> mes("souls in Niflheim are simply")
        |> mes("doomed to suffer. That's the")
        |> mes("nature of this realm and one")
        |> mes("of the rules of balance...")
        |> next()
        |> mes("[Serin]")
        |> mes("It was child's play to ask")
        |> mes("some adventurers to help")
        |> mes("these souls. But once they learn that these souls can't be helped,")
        |> mes("it's too late! In failing them, the adventurers add to their despair!")
        |> next()
        |> mes("[Serin]")
        |> mes("And by increasing")
        |> mes("the despair here, it")
        |> mes("also adds to the power I'll")
        |> mes("use to summon Dark Lord!")
        |> next()
      end

    ctx
    |> mes("[Serin]")
    |> mes("I don't want us to fight,")
    |> mes("but I can't let you stop me.")
    |> mes("I've already sold my soul to")
    |> mes("Dark Lord to become a living")
    |> mes("human again so I can't give up")
    |> mes("now! We'll have to battle!")
    |> close2()
    |> set_char_var(:sign_q, 126)
    |> donpcevent("CallMonster#witch::Oncall")
    |> donpcevent("Serin#witch::OnDisable")
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("I see now.")
    |> mes("Soon, I'll lose my memories")
    |> mes("and remain dead in Niflheim.")
    |> mes("Just like all the others. Still,")
    |> mes("may I ask you one question?")
    |> next()
    |> mes("[Serin]")
    |> mes("With that symbol, you")
    |> mes("could order the dead to do")
    |> mes("whatever you want. Why didn't")
    |> mes("you use it to command me to quit?")
    |> next()
    |> mes("[Serin]")
    |> mes("...")
    |> mes("......")
    |> mes("..........")
    |> next()
    |> mes("[Serin]")
    |> mes("I see it now.")
    |> mes("The kindness in your eyes")
    |> mes(
      "tells me everything. You wanted to give me another chance. But in the end, I managed to destroy the"
    )
    |> mes("chance you had given me.")
    |> next()
    |> mes("[Serin]")
    |> mes("Even though I'm nothing but")
    |> mes("a spirit now, it was an honor")
    |> mes(
      "for me to meet somebody like you. Although I'll lose my memories, I'll try not to forget you."
    )
    |> next()
    |> mes("[Serin]")
    |> mes("My memories of your")
    |> mes("courage and kindness")
    |> mes("are more precious to")
    |> mes("me than life itself.")
    |> next()
    |> mes("[Serin]")
    |> mes("Farewell, now.")
    |> mes("And good luck on")
    |> mes("your travels, my friend...")
    |> delitem(7308, 1)
    |> set_char_var(:sign_q, 127)
    |> close()
  end

  defp return_to_niflheim(ctx) do
    ctx
    |> mes("^3355FFYou helped the")
    |> mes("unconscious Serin")
    |> mes("and returned to Niflheim.^000000")
    |> close2()
    |> set_char_var(:sign_q, 128)
    |> set_server_temp_var("sign_w1", 0)
    |> warp("que_sign01", 117, 137)
  end

  defp retry(ctx) do
    ctx =
      ctx
      |> set_local(:fail_s1, Enum.random(1..1000))
      |> set_local(:fail_s2, Enum.random(1..900))
      |> set_local(:fail_s3, Enum.random(1..800))
      |> set_local(:fail_s4, Enum.random(1..700))
      |> set_local(:fail_s5, Enum.random(1..600))

    defeated? =
      if count_item(ctx, 2643) == 1 do
        (get_char_var(ctx, :sign_sq, 0) == 0 and get_local(ctx, :fail_s3, 0) == 356) or
          (get_char_var(ctx, :sign_sq, 0) == 1 and get_local(ctx, :fail_s2, 0) == 356) or
          get_local(ctx, :fail_s1, 0) == 356
      else
        (get_char_var(ctx, :sign_sq, 0) == 0 and get_local(ctx, :fail_s5, 0) == 356) or
          (get_char_var(ctx, :sign_sq, 0) == 1 and get_local(ctx, :fail_s4, 0) == 356) or
          get_local(ctx, :fail_s3, 0) == 356
      end

    if defeated? do
      ctx
      |> delitem(7308, 1)
      |> set_char_var(:sign_q, 200)
      |> mes("[Serin]")
      |> mes("Even though you tried")
      |> mes("to stop me, I still don't wish")
      |> mes("to take your life. I understand")
      |> mes("that you've merely trying to")
      |> mes("protect your Midgard.")
      |> next()
      |> mes("[Serin]")
      |> mes("However...")
      |> mes("I do not think you")
      |> mes("have the courage to")
      |> mes("overcome the ordeals ")
      |> mes("of the gods. Please don't")
      |> mes("come here anymore...")
      |> next()
      |> mes("^3355FFSerin took")
      |> mes("1 Witch's Tonic")
      |> mes("from you.^000000")
      |> next()
      |> mes("[Serin]")
      |> mes("I'm sorry...")
      |> mes("But I'm taking")
      |> mes("your Witch's Tonic")
      |> mes("to help me summon")
      |> mes("Dark Lord. Farewell...")
      |> close2()
      |> set_server_temp_var("sign_w1", 0)
      |> warp("niflheim", 30, 156)
    else
      ctx
      |> mes("[Serin]")
      |> mes("Haven't you")
      |> mes("given up yet?")
      |> mes("Please don't")
      |> mes("try to stop me!")
      |> close2()
      |> set_char_var(:sign_q, 126)
      |> donpcevent("Serin#witch::OnDisable")
      |> donpcevent("CallMonster#witch::Oncall")
    end
  end

  defp send_to_midgard(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("Let me guide")
    |> mes("you to where")
    |> mes("you belong.")
    |> mes(".......")
    |> close2()
    |> set_server_temp_var("sign_w1", 0)
    |> warp("umbala", 132, 203)
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "Serin#witch")
  end

  def ev_onenable(ctx) do
    enablenpc(ctx, "Serin#witch")
  end
end
