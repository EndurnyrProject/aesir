defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Sneak do
  @moduledoc """
  A hidden trigger controls access to the Secret Archive.

  ## Behavior

  - Offers entry when guards leave, provided the player has a card and password.
  - Ejects players after three incorrect password attempts.

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
        map: "lhz_in01",
        x: 187,
        y: 31,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Sneak",
        trigger: {4, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :lhz_boss, 0) > 27 and get_char_var(ctx, :lhz_boss, 0) < 35 do
      ctx = set_temp_var(ctx, :sneaktime, rem(gettimetick(ctx, 0), 100))
      time = get_temp_var(ctx, :sneaktime, 0)

      if (time > 10 and time < 59) or (time < -10 and time > -59),
        do: wait_for_guards(ctx),
        else: ctx
    else
      ctx
    end
  end

  defp wait_for_guards(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFAs you approach")
      |> mes("the corner, you can")
      |> mes("hear hushed whispers")
      |> mes("just over the wall.^000000")
      |> next()
      |> mes("[Senior Guard]")
      |> mes("Hey, my shift is over.")
      |> mes("Hurry and get the next")
      |> mes("guy to relieve me, will you?")
      |> next()
      |> mes("[Rookie Guard]")
      |> mes("Already?")
      |> mes("Wow, time sure")
      |> mes("flies fast. Fine,")
      |> mes("wait here a bit.")
      |> next()
      |> mes("^3355FFOne of the guards left")
      |> mes("his post, and now there")
      |> mes("is only one remaining")
      |> mes("guard monitoring this area.^000000")
      |> next()
      |> mes("[Senior Guard]")
      |> mes("Criminy...")
      |> mes("I need to go to")
      |> mes("the bathroom. Well,")
      |> mes("I'm sure nothing will")
      |> mes("happen while I'm gone.")
      |> next()
      |> mes("^3355FFYou listen to the")
      |> mes("guard's footsteps as")
      |> mes("they grow fainter and")
      |> mes("fainter into the distance.^000000")
      |> next()
      |> select(["Sneak in now.", "Wait for another chance."])

    case choice do
      1 -> approach_door(ctx)
      2 -> retreat(ctx)
      _ -> ctx
    end
  end

  defp approach_door(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis is the perfect")
      |> mes("opportunity to infiltrate")
      |> mes("the Secret Archive! You")
      |> mes("approach the door and")
      |> mes("find a device where you")
      |> mes("can insert Lestin's card pass.^000000")
      |> next()
      |> select(["Insert Card", "Retreat"])

    case choice do
      1 -> insert_card(ctx)
      2 -> retreat(ctx)
      _ -> ctx
    end
  end

  defp insert_card(ctx) do
    if not Rathena.truthy?(count_item(ctx, 7349)) do
      ctx
      |> mes("^3355FFYou forgot to bring")
      |> mes("the card pass that")
      |> mes("you got from Lestin.")
      |> mes("You need it in order")
      |> mes("to open this door.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFAfter inserting the")
      |> mes("pass, a panel within")
      |> mes("the door slides open,")
      |> mes("revealing a numeric keypad.")
      |> mes("You need to input the correct")
      |> mes("password to open the door.^000000")
      |> next()
      |> enter_password()
    end
  end

  defp retreat(ctx) do
    ctx
    |> mes("^3355FFPerhaps now would")
    |> mes("not be the best time to")
    |> mes("enter the Secret Archive.")
    |> mes("Or at least, that's what")
    |> mes("you've decided for yourself.^000000")
    |> close()
  end

  defp enter_password(ctx) do
    {ctx, password} = input(ctx, :int)
    ctx = set_temp_var(ctx, :sneakpass, password)

    if get_temp_var(ctx, :sneakpass, 0) == 738_495,
      do: unlock_door(ctx),
      else: wrong_password(ctx)
  end

  defp unlock_door(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FF*Beep~*")
      |> mes("You hear a pleasant")
      |> mes("sounding electronic chirp,")
      |> mes("signaling that you have input")
      |> mes("the correct password. The door")
      |> mes("automatically slides open.")
      |> next()
      |> select(["Enter", "Retreat"])

    case choice do
      1 ->
        ctx
        |> mes("[Security System]")
        |> mes("You have 3 minutes to")
        |> mes("search the Information Archive.")
        |> mes("When this time elapses, you")
        |> mes("will be automatically sent")
        |> mes("outside for security reasons.")
        |> close2()
        |> set_char_var(:lhz_boss, 29)
        |> donpcevent("Timer_Sneak::OnEnter")
        |> warp("lhz_in01", 177, 35)

      2 ->
        retreat(ctx)

      _ ->
        ctx
    end
  end

  defp wrong_password(ctx) do
    ctx =
      ctx
      |> mes("^3355FF*Eeeeeee*")
      |> mes("The door emits an")
      |> mes("unnerving, high pitched")
      |> mes("screech after you input")
      |> mes("the password. You really")
      |> mes("should try to input it again.^000000")

    ctx = ctx |> set_temp_var(:sneakerror, get_temp_var(ctx, :sneakerror, 0) + 1) |> next()

    if get_temp_var(ctx, :sneakerror, 0) > 2 do
      ctx
      |> mes("[Security System]")
      |> mes("*Gzzzzz*")
      |> mes("You have entered the")
      |> mes("password incorrectly")
      |> mes("3 times. Please stand by")
      |> mes("for managerial assistance.")
      |> next()
      |> mes("^3355FFUh oh!")
      |> mes("You better get")
      |> mes("out of here before")
      |> mes("you get caught!^000000")
      |> close2()
      |> warp("lhz_in01", 191, 49)
    else
      enter_password(ctx)
    end
  end
end
