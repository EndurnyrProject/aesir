defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Security do
  @moduledoc """
  A security system controls access to the Einbroch laboratory.

  ## Behavior

  - Eligible visitors must type two randomly selected passwords within 60 seconds.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 51,
        y: 52,
        dir: 0,
        sprite: 45,
        name: "Security",
        scope: :shared,
        unique_name: "Security#ein",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :Shinokas_Quest, 0) == 7 or get_char_var(ctx, :lhz_heart, 0) == 9 or
         get_char_var(ctx, :lhz_heart, 0) == 10 do
      {ctx, choice} =
        ctx
        |> mes("[Security System]")
        |> mes("^8B0000*Beep Boop*^000000")
        |> mes("Restricted Access Area.")
        |> mes("Please identify yourself")
        |> mes("through the system.")
        |> next()
        |> select(["Identify.", "Information", "Cancel"])

      case choice do
        1 ->
          identify(ctx)

        2 ->
          information(ctx)

        3 ->
          ctx
          |> mes("[Security System]")
          |> mes("You have canceled")
          |> mes("the ID security check.")
          |> close()

        _ ->
          ctx
      end
    else
      ctx |> mes("^3355FFThe door is locked.") |> mes("You cannot enter.^000000") |> close()
    end
  end

  @impl true
  def on_talk(ctx), do: ctx

  defp identify(ctx) do
    ctx =
      ctx
      |> mes("[Security System]")
      |> mes("Enter the following")
      |> mes("password in 60 seconds.")
      |> mes("Failure to do so will result")
      |> mes("in lockout. Please wait.")
      |> next()

    started = gettimetick(ctx, 1)
    ctx = mes(ctx, "[Security System]")
    {first, second, color, split?} = passwords(Enum.random(1..7))

    ctx =
      if split? do
        ctx
        |> mes("^3CBCBCBy the power of p-po-poi-po-poi-poin-poing")
        |> mes("GOD-POING. I NEVER LOSE!^000000")
      else
        mes(ctx, "^3CBCBC" <> first <> "^000000")
      end

    {ctx, first_input} = ctx |> next() |> input(:string)

    {ctx, second_input} =
      ctx
      |> mes("[Security System]")
      |> mes(color <> second <> "^000000")
      |> next()
      |> input(:string)

    elapsed = gettimetick(ctx, 1) - started
    ctx = mes(ctx, "[Security System]")

    cond do
      first_input != first or second_input != second ->
        ctx
        |> mes("You have failed")
        |> mes("the identification")
        |> mes("check. Access denied.")
        |> close()

      elapsed > 60 ->
        ctx
        |> mes("Time over.")
        |> mes("It took ^ff0000#{elapsed} seconds^000000")
        |> mes("for you to enter the")
        |> mes("password. Initiating")
        |> mes("lockout. Access denied.")
        |> close()

      true ->
        ctx
        |> mes("It took ^ff0000#{elapsed} seconds^000000")
        |> mes("for you to enter the")
        |> mes("password. Initiating")
        |> mes("override. Access granted.")
        |> close()
        |> warp("ein_in01", 283, 25)
    end
  end

  defp passwords(1),
    do:
      {"burrdingdingdilidingdingphoohudaambandoorabambarambambamburanbamding",
       "burapaphurarlandreamduranbatuhiwooikabamturubamdingding", "^FF1493", false}

  defp passwords(2),
    do:
      {"...silence. quiet benevolence... soul mate... wonder. enigma... cloud.",
       "opeN,Open!op3n.openOpen0p3nOpEn0pen`open'0Pen open?open!111OPENSESAME", "^FF1493", false}

  defp passwords(3),
    do:
      {"Coboman no chikara-yumei na chikara-daiookii na chikara da ze! COBO ON",
       "hfjdkeldjsieldjshfjdjeiskdlefvbd", "^FF1493", false}

  defp passwords(4),
    do:
      {"belief love luck grimace sweat rush folktale rodimus optimus bumblebee",
       "LiGhTsPeEd RiGhT SPEed LeFT TURn RiGhT BuRn OrIGInAL GaNgSteR SmACk", "^FF1493", false}

  defp passwords(5),
    do:
      {"By the power of p-po-poi-po-poi-poin-poing GOD-POING. I NEVER LOSE!",
       "uNflAPPaBLe LoVaBLe SeCreTs AnD BoWLiNg aGaINST tHe KarMA of YoUtH", "^FF1493", true}

  defp passwords(6),
    do:
      {"You give me no choice. I guess it's time for me to reveal my secret...",
       "fReeDoM eCstAcy JoUrnaLiSm ArMpIt DisCoverY hEaDaChE MoonbeAmS jUsTiCE", "^800080", false}

  defp passwords(7),
    do:
      {"I'm the King of All Weirdos! Now you know of my true power. Obey~!",
       "uNflAPPaBLe LoVaBLe SeCreTs AnD BoWLiNg aGaINST tHe KarMA of YoUtH", "^800080", false}

  defp information(ctx) do
    ctx
    |> mes("[Security System]")
    |> mes("You must use the")
    |> mes("security system in order")
    |> mes("to gain access into the")
    |> mes("Einbroch Laboratory.")
    |> next()
    |> mes("[Security System]")
    |> mes("You will be given")
    |> mes("a password that you")
    |> mes("must input correctly")
    |> mes("within 60 seconds.")
    |> mes("Otherwise, you will")
    |> mes("fail the security check.")
    |> next()
    |> mes("[Security System]")
    |> mes("If you take longer")
    |> mes("than 3 minutes to")
    |> mes("enter the password,")
    |> mes("the security system")
    |> mes("will initiate lockout.")
    |> close()
  end
end
