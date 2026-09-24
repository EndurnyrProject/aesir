defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.Thomas do
  @moduledoc """
  Examiner of the Assassin hiding test, where applicants must cross a monster-filled room
  without killing anything.

  ## Behavior

  - Explains the test and spawns the Mummies and Hydras that must not be killed.
  - Applicants returning mid-test are fully healed and may retry or quit; quitting resets
    the test progress and sends them to the guild entrance.
  - When disabled, removes the test monsters and reopens the standby room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 89,
        y: 98,
        dir: 1,
        sprite: 118,
        name: "Thomas",
        scope: :shared,
        unique_name: "Thomas#ASNTEST",
        trigger: {5, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @mob_event "timestopper#1::OnMyMobDead"

  @test_monsters [
    {1041, {81, 77}},
    {1041, {82, 77}},
    {1041, {83, 77}},
    {1041, {84, 77}},
    {1041, {85, 77}},
    {1041, {86, 77}},
    {1041, {88, 77}},
    {1041, {89, 77}},
    {1041, {90, 77}},
    {1041, {77, 77}},
    {1041, {78, 56}},
    {1041, {79, 56}},
    {1041, {80, 56}},
    {1041, {81, 56}},
    {1041, {91, 55}},
    {1041, {92, 56}},
    {1041, {93, 56}},
    {1041, {94, 56}},
    {1041, {95, 56}},
    {1041, {96, 56}},
    {1041, {97, 56}},
    {1068, {76, 62}},
    {1068, {79, 62}},
    {1068, {79, 65}},
    {1068, {76, 65}},
    {1068, {96, 62}},
    {1068, {96, 65}},
    {1068, {99, 62}},
    {1068, {99, 65}}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :ASSIN_Q, 0) == 4 do
      offer_retry(ctx)
    else
      start_test(ctx)
    end
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> donpcevent("Standby Room#ASNTEST::OnStart")
    |> killmonster("in_moc_16", @mob_event)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp offer_retry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Thomas]")
      |> mes(
        "Damn...! You look like you're in a lot of pain. ^666666*Sigh*^000000 Give me a second, let me try to restore your HP and SP..."
      )
      |> percent_heal(hp: 100, sp: 100)
      |> next()
      |> mes("[Thomas]")
      |> mes(
        "It looks like you're having a tough time. You're either trying too hard, or not trying hard"
      )
      |> mes("enough, kid.")
      |> next()
      |> select(["I'm gonna try it again!", "I... I quit!"])

    case choice do
      1 ->
        ctx
        |> mes("[Thomas]")
        |> mes("Hmm. Well, okay.")
        |> mes("Good luck out there.")
        |> close()

      2 ->
        quit_test(ctx)

      _ ->
        start_test(ctx)
    end
  end

  defp quit_test(ctx) do
    ctx =
      ctx
      |> mes("[Thomas]")
      |> mes("Huh...")
      |> mes("Quit the test, eh? Well, I guess you don't wanna waste any more of our time.")
      |> next()
      |> mes("[Thomas]")
      |> mes("Oh hey, don't forget to save your respawn point in town.")
      |> close()

    ctx
    |> mapannounce(
      "in_moc_16",
      "#{char_name(ctx, 0)} got scared and quit the test...Who's Next?!",
      1
    )
    |> set_char_var(:ASSIN_Q, 0)
    |> set_char_var(:ASSIN_Q2, 0)
    |> changequest(8004, 8000)
    |> savepoint("in_moc_16", 18, 14)
    |> warp("in_moc_16", 18, 14)
    |> donpcevent("Standby Room#ASNTEST::OnStart")
  end

  defp start_test(ctx) do
    ctx
    |> mes("[Thomas]")
    |> mes(
      "Hey, I'm Thomas. I'm in charge of testing your use of the hiding skill. Think you're up to it?"
    )
    |> next()
    |> mes("[Thomas]")
    |> mes(
      "Listen. In this test, you can't kill any monsters. Your goal is to reach 'Barcardi' at the opposite side of this room."
    )
    |> next()
    |> mes("[Thomas]")
    |> mes(
      "So basically, get to the other side of this room and meet 'Barcardi' without killing a single monster. Understand?"
    )
    |> next()
    |> mes("[Thomas]")
    |> mes(
      "If you run away, get a nose bleed and pass out or something like that, I'll fail ya'. Enough talk. Let's see what you got."
    )
    |> close()
    |> set_char_var(:ASSIN_Q, 4)
    |> summon_test_monsters()
  end

  defp summon_test_monsters(ctx) do
    Enum.reduce(@test_monsters, ctx, fn {mob_id, at}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: "in_moc_16", at: at, event: @mob_event)
    end)
  end
end
