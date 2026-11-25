defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Guard9571 do
  @moduledoc """
  Guards access to the president and introduces his departing guest.

  ## Behavior

  - Enforces the building rules and asks visitors to wait.
  - Introduces Keshnaar before allowing the player to enter.

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
    spawn: [%{map: "yuno_pre", x: 95, y: 71, dir: 5, sprite: 852, name: "Guard", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_boss, 0) do
      stage when stage < 11 ->
        ctx
        |> mes("[Guard]")
        |> mes("You are in the")
        |> mes("President's House.")
        |> mes("Arms are prohibited")
        |> mes("without authorization in")
        |> mes("this government building.")
        |> mes("Thank you for your cooperation.")
        |> close2()
        |> nude()
        |> warp("yuno_pre", 83, 22)

      stage when stage in [11, 12] ->
        wait_for_guest(ctx, stage)

      13 ->
        enter_or_ask(ctx)

      _ ->
        ctx
        |> mes("[Guard]")
        |> mes("Greetings.")
        |> mes("You may enter to")
        |> mes("see the president.")
        |> close2()
        |> warp("yuno_pre", 78, 69)
    end
  end

  defp wait_for_guest(ctx, stage) do
    ctx = if stage == 12, do: set_temp_var(ctx, :visit_pre, Enum.random(1..10)), else: ctx

    if get_temp_var(ctx, :visit_pre, 0) == 7 do
      introduce_guest(ctx)
    else
      ctx =
        ctx
        |> mes("[Guard]")
        |> mes("Please wait a moment.")
        |> mes("Currently, the president")
        |> mes("is seeing another guest.")
        |> mes("Thank you for your patience.")

      ctx =
        if get_char_var(ctx, :lhz_boss, 0) == 11, do: set_char_var(ctx, :lhz_boss, 12), else: ctx

      close(ctx)
    end
  end

  defp introduce_guest(ctx) do
    ctx =
      ctx
      |> mes("[?????]")
      |> mes("I see.")
      |> mes("Then...")
      |> next()
      |> mes("[????????]")
      |> mes("Ummm....")
      |> mes("Understood...")
      |> mes("......")
      |> next()
      |> enablenpc("A Fine Gentleman")
      |> next()
      |> mes("[?????]")
      |> mes("..........")
      |> next()
      |> mes("[Guard]")
      |> mes("Ah, Mr. Keshnaar.")
      |> mes("Are you leaving?")
      |> next()
      |> mes("[Keshnaar]")
      |> mes("Yes, it's about time")
      |> mes("for me to depart. Ah,")
      |> mes("and may I ask who this")

    ctx =
      if sex(ctx) == 1,
        do: mes(ctx, "young gentleman here is?"),
        else: mes(ctx, "lovely young lady is?")

    ctx = ctx |> next() |> mes("[Guard]") |> mes("Mr. Keshnaar,")
    ctx = mes(ctx, Rathena.concat(Rathena.concat("I present ", char_name(ctx, 0)), "."))

    ctx
    |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ", allow me"))
    |> mes("to introduce Eridan Keshnaar.")
    |> next()
    |> mes("[Keshnaar]")
    |> mes("A pleasure to meet you.")
    |> mes("Now, if you would excuse")
    |> mes("me, I have some business")
    |> mes("to attend to. Good day~")
    |> next()
    |> mes("[Guard]")
    |> mes("Take care,")
    |> mes("Mr. Keshnaar.")
    |> set_char_var(:lhz_boss, 13)
    |> disablenpc("A Fine Gentleman")
    |> close()
  end

  defp enter_or_ask(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guard]")
      |> mes("Now you may enter")
      |> mes("and speak with the")
      |> mes("president. Thank you")
      |> mes("for waiting all this time.")
      |> next()
      |> select(["Thank you.", "Who was that gentleman...?"])

    case choice do
      1 ->
        notify_president(ctx)

      2 ->
        ctx
        |> mes("[Guard]")
        |> mes("Oh, Mr. Keshnaar is the")
        |> mes("government negotiator from")
        |> mes("the Rekenber Corporation.")
        |> mes("He often visits the president")
        |> mes("to discuss various issues.")
        |> set_char_var(:lhz_boss, 14)
        |> close()

      _ ->
        ctx
    end
  end

  defp notify_president(ctx) do
    title =
      cond do
        sex(ctx) == 1 -> "A Mister "
        Rathena.truthy?(getpartnerid(ctx)) -> "A Missis "
        true -> "A Miss "
      end

    ctx = mes(ctx, Rathena.concat(Rathena.concat(title, char_name(ctx, 0)), ""))

    ctx
    |> mes("has arrived to see you now.")
    |> next()
    |> mes(".....")
    |> next()
    |> mes("[Mr. President]")
    |> mes("Oh, you're early!")
    |> mes("I'm sorry, but would you")
    |> mes("please wait one minute?")
    |> next()
    |> mes("[Guard]")
    |> mes("Yes, sir.")
    |> mes("My apologies, but would")
    |> mes("you please wait until the")
    |> mes("president is ready?")
    |> close()
  end
end
