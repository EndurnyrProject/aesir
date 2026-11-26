defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Serin19639 do
  @moduledoc """
  Guides the confrontation with Serin and the Dark Lord.

  ## Behavior

  - Receives the symbol and reveals Serin's plan to summon the Dark Lord.
  - Resolves the player's choice, combat retries, and return from the encounter.

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
        x: 196,
        y: 39,
        dir: 4,
        sprite: 90,
        name: "Serin",
        scope: :shared,
        unique_name: "Serin#serin"
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

    cond do
      get_char_var(ctx, :sign_q, 0) < 132 ->
        ctx |> mes("[Serin]") |> mes("....?") |> close()

      get_char_var(ctx, :sign_q, 0) == 132 ->
        receive_symbol(ctx)

      get_char_var(ctx, :sign_q, 0) == 133 ->
        confront_serin(ctx)

      get_char_var(ctx, :sign_q, 0) == 134 ->
        serin_farewell(ctx)

      get_char_var(ctx, :sign_q, 0) == 135 ->
        return_to_niflheim(ctx)

      get_char_var(ctx, :sign_q, 0) == 199 ->
        resolve_defeat(ctx)

      get_char_var(ctx, :sign_q, 0) == 200 ->
        return_to_midgard(ctx)

      true ->
        ctx |> mes("..........") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp receive_symbol(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("As its magic power grows,")
      |> mes(
        "the Magic Circle is nearing completion. The symbol which I've asked you for is the last material needed for summoning Dark Lord."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("However, the power of that")
      |> mes("symbol can be used to complete")
      |> mes("the Magic Circle or destroy it.")
      |> mes("Would you hand it over to me?")
      |> mes("I choose to destroy this...")
      |> next()
      |> mes("[Serin]")
      |> mes("Please...")
      |> mes("Let me have the symbol.")
      |> next()
      |> select(["Give Serin the symbol."])

    ctx
    |> mes("[Serin]")
    |> mes("This could be")
    |> mes("pretty dangerous")
    |> mes("so please step back...")
    |> delitem(7305, 1)
    |> set_char_var(:sign_q, 133)
    |> donpcevent("Serin#dummy::OnEnable")
    |> donpcevent("Serin#dummy::OnStart")
    |> donpcevent("Serin#serin::OnDisable")
    |> close()
  end

  defp confront_serin(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("I'm sorry.")
      |> mes("But I have to do this")
      |> mes("to summon Dark Lord.")
      |> next()
      |> select(["But why...?"])

    {ctx, _} =
      ctx
      |> mes("[Serin]")
      |> mes("It was never the witch")
      |> mes("that wanted Dark Lord summoned,")
      |> mes(
        "but me. I've always wanted to return to my human form. I'm sick and tired of being bound here in Niflheim!"
      )
      |> next()
      |> mes("[Serin]")
      |> mes("Unfortunately, the symbol")
      |> mes("which Lady Hell gave you is")
      |> mes("limited to a one time use. Its")
      |> mes("power wasn't enough to bring me")
      |> mes("back, so summoning Dark Lord is")
      |> mes("my last chance.")
      |> next()
      |> select(["But if Dark Lord comes to Midgard..."])

    {ctx, choice} =
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
      |> mes("However, by summoning Dark Lord,")
      |> mes(
        "you might be thinking it'd be pretty pointless for me to come back. But you know what? I don't care."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("The living don't appreciate")
      |> mes("what they have, so they ought")
      |> mes(
        "to be punished. They can all go to Niflheim while I enjoy the warmth of the sun and the fresh outside air."
      )
      |> next()
      |> mes("[Serin]")
      |> mes("Maybe you might not")
      |> mes("pity my situation since you've")
      |> mes("never been bound to Niflheim,")
      |> mes("but I'm begging you. Don't get")
      |> mes("in my way.")
      |> next()
      |> select(["Alright. I'll let you go.", "No, you have to be stopped."])

    case choice do
      1 ->
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
            ctx
            |> mes("[Serin]")
            |> mes("...")
            |> mes("I really don't want to fight you,")
            |> mes(
              "but I've come too far to give up now. If you insist on interfering, then you leave me no choice..."
            )
            |> next()
            |> donpcevent("Dark Lord#serin::OnEnable")
            |> mes("[Dark Lord]")
            |> mes("^330033Insolent mortal!")
            |> mes("Do you really think")
            |> mes("you have a chance of")
            |> mes("stopping me? Hmpf.")
            |> mes("Every fool must learn.")
            |> mes("Prepare to die!^000000")
            |> set_char_var(:sign_q, 134)
            |> donpcevent("Serin#serin::OnDisable")
            |> donpcevent("Dark Lord#serin::OnDisable")
            |> donpcevent("CallMonster#serin::Oncall")
            |> close()

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
            |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 20000, else: 200_000), 0)
            |> set_server_temp_var("sign_w2", 0)
            |> donpcevent("Dark Lord#serin::OnDisable")
            |> close2()
            |> warp("umbala", 132, 203)

          _ ->
            ctx
        end

      2 ->
        ctx =
          ctx
          |> mes("[Serin]")
          |> mes("...")
          |> mes("I really don't want to fight you,")
          |> mes(
            "but I've come too far to give up now. If you insist on interfering, then you leave me no choice..."
          )
          |> next()

        ctx
        |> emotion(:kik, getnpcid(ctx, "Dark Lord#serin"))
        |> mes("[Dark Lord]")
        |> mes("^330033Insolent mortal!")
        |> mes("Do you really think")
        |> mes("you have a chance of")
        |> mes("stopping me? Hmpf.")
        |> mes("Every fool must learn.")
        |> mes("Prepare to die!^000000")
        |> set_char_var(:sign_q, 134)
        |> donpcevent("Serin#serin::OnDisable")
        |> donpcevent("Dark Lord#serin::OnDisable")
        |> donpcevent("CallMonster#serin::Oncall")
        |> close()

      _ ->
        ctx
    end
  end

  defp serin_farewell(ctx) do
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
    |> set_char_var(:sign_q, 135)
    |> close()
  end

  defp return_to_niflheim(ctx) do
    ctx
    |> mes("^3355FFYou helped the")
    |> mes("unconscious Serin")
    |> mes("and returned to Niflheim.^000000")
    |> close2()
    |> set_char_var(:sign_q, 136)
    |> set_server_temp_var("sign_w2", 0)
    |> warp("que_sign01", 117, 137)
  end

  defp resolve_defeat(ctx) do
    ctx =
      ctx
      |> set_local(:fail_s1, Enum.random(1..800))
      |> set_local(:fail_s2, Enum.random(1..700))
      |> set_local(:fail_s3, Enum.random(1..600))
      |> set_local(:fail_s4, Enum.random(1..500))
      |> set_local(:fail_s5, Enum.random(1..400))

    banish? =
      if count_item(ctx, 2643) == 1 do
        (get_char_var(ctx, :sign_sq, 0) == 0 and get_local(ctx, :fail_s3, 0) == 356) or
          (get_char_var(ctx, :sign_sq, 0) == 1 and get_local(ctx, :fail_s2, 0) == 356) or
          get_local(ctx, :fail_s1, 0) == 356
      else
        (get_char_var(ctx, :sign_sq, 0) == 0 and get_local(ctx, :fail_s5, 0) == 356) or
          (get_char_var(ctx, :sign_sq, 0) == 1 and get_local(ctx, :fail_s4, 0) == 356) or
          get_local(ctx, :fail_s3, 0) == 356
      end

    if banish?, do: banish_player(ctx), else: retry_fight(ctx)
  end

  defp return_to_midgard(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("Let me guide")
    |> mes("you to where")
    |> mes("you belong.")
    |> close2()
    |> warp("umbala", 132, 203)
  end

  defp banish_player(ctx) do
    ctx
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
    |> mes("[Serin]")
    |> mes("Farewell...")
    |> close2()
    |> set_server_temp_var("sign_w2", 0)
    |> warp("niflheim", 30, 156)
  end

  defp retry_fight(ctx) do
    ctx
    |> mes("[Serin]")
    |> mes("Haven't you")
    |> mes("given up yet?")
    |> mes("Please don't")
    |> mes("try to stop me!")
    |> close2()
    |> set_char_var(:sign_q, 134)
    |> donpcevent("Serin#serin::OnDisable")
    |> donpcevent("Dark Lord#serin::OnDisable")
    |> donpcevent("CallMonster#serin::Oncall")
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "Serin#serin")
  end

  def ev_onenable(ctx) do
    enablenpc(ctx, "Serin#serin")
  end
end
