defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.Manager do
  @moduledoc """
  Hidden controller that runs the timed Hunter test in the arena.

  ## Behavior

  - Starts a test by spawning target monsters among many decoys and a countdown of arena announcements.
  - Opens the escape switch once enough target monsters are hunted.
  - Sends the examinee back to the waiting area for killing a decoy.
  - Clears the arena when the test ends or times out and reopens the waiting room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_hunte",
        x: 1,
        y: 1,
        dir: 1,
        sprite: 66,
        name: "Manager",
        scope: :shared,
        unique_name: "Manager#hnt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @target_mobs [
    {1015, {67, 80}},
    {1015, {114, 78}},
    {1002, {89, 127}},
    {1041, {53, 73}},
    {1016, {125, 70}},
    {1015, {90, 92}}
  ]

  @decoy_mobs [
    {1016, {85, 100}},
    {1041, {72, 102}},
    {1015, {108, 103}},
    {1002, {88, 127}},
    {1015, {125, 69}},
    {1016, {77, 112}},
    {1015, {53, 106}},
    {1002, {53, 73}},
    {1015, {125, 70}},
    {1015, {90, 91}},
    {1015, {67, 80}},
    {1016, {77, 112}},
    {1015, {53, 106}},
    {1015, {53, 73}},
    {1015, {125, 70}},
    {1041, {90, 91}},
    {1002, {85, 100}},
    {1015, {72, 102}},
    {1015, {108, 103}},
    {1015, {77, 112}},
    {1015, {112, 139}},
    {1015, {112, 139}},
    {1015, {112, 139}},
    {1015, {112, 139}},
    {1015, {90, 91}},
    {1002, {53, 73}},
    {1015, {53, 106}},
    {1015, {77, 112}},
    {1015, {72, 102}},
    {1015, {108, 103}}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Manager#hnt")

  def on_event("OnEnable", ctx) do
    ctx
    |> donpcevent("Switch#hnt::OnDisable")
    |> enablenpc("Manager#hnt")
    |> set_npc_var("MyMobs", 6)
    |> initnpctimer()
    |> summon_all(@target_mobs, "Manager#hnt::OnMyMobDead")
    |> summon_all(@decoy_mobs, "Manager#hnt::OnMyMobDead2")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 3 do
      ctx
      |> announce(
        "Okay, good job... Now, find the switch in the center of the map!! Be careful of the traps!!"
      )
      |> set_char_var(:HNTR_Q, 14)
      |> donpcevent("switch#hnt::OnEnable")
      |> donpcevent("Manager#hnt::OnDisable")
    else
      announce(ctx, "Okay~ You're almost there!!")
    end
  end

  def on_event("OnMyMobDead2", ctx) do
    ctx
    |> announce("#{char_name(ctx, 0)}!! You made a mistake...Please try again.")
    |> set_char_var(:HNTR_Q, 13)
    |> warp("job_hunte", 176, 22)
    |> donpcevent("Manager#hnt::OnReset")
    |> donpcevent("Waiting Room#hnt::OnStart")
  end

  def on_event("OnReset", ctx), do: stopnpctimer(ctx)

  def on_event("OnDisable", ctx) do
    ctx
    |> killmonsterall("job_hunte")
    |> disablenpc("Manager#hnt")
  end

  def on_event("OnTimer1000", ctx), do: announce(ctx, "The test shall now begin.")

  def on_event("OnTimer3000", ctx) do
    announce(ctx, "As mentioned before, only hunt the monsters labeled 'Job change monster'.")
  end

  def on_event("OnTimer5000", ctx) do
    announce(ctx, "***** Be careful of the traps when hunting. *****")
  end

  def on_event("OnTimer7000", ctx) do
    announce(
      ctx,
      "Once you hunt 4 'Job change monster' the switch in the center will begin to operate."
    )
  end

  def on_event("OnTimer9000", ctx) do
    announce(
      ctx,
      "When you activate the escape switch, exit the testing area through the warp portal in the 12 o'clock direction."
    )
  end

  def on_event("OnTimer11000", ctx) do
    announce(ctx, "Everything must be completed within 3 minutes.")
  end

  def on_event("OnTimer13000", ctx) do
    announce(
      ctx,
      "You will have 3 minutes from now on. You will be notified after each minute passes."
    )
  end

  def on_event("OnTimer14000", ctx), do: announce(ctx, " ****** 3 minutes remaining. ****** ")
  def on_event("OnTimer74000", ctx), do: announce(ctx, " ****** 2 minutes remaining. ****** ")
  def on_event("OnTimer134000", ctx), do: announce(ctx, " ****** 1 minute remaining. ****** ")
  def on_event("OnTimer164000", ctx), do: announce(ctx, " ****** 30 seconds remaining. ****** ")
  def on_event("OnTimer187000", ctx), do: announce(ctx, " Test ends in 5 seconds...")
  def on_event("OnTimer188000", ctx), do: announce(ctx, " Test ends in 4 seconds...")
  def on_event("OnTimer189000", ctx), do: announce(ctx, " Test ends in 3 seconds...")
  def on_event("OnTimer191000", ctx), do: announce(ctx, " Test ends in 2 seconds...")
  def on_event("OnTimer192000", ctx), do: announce(ctx, " Test ends in 1 second.")
  def on_event("OnTimer193000", ctx), do: announce(ctx, " 0 ")
  def on_event("OnTimer194000", ctx), do: announce(ctx, " Time's up. Please try again.")

  def on_event("OnTimer195000", ctx) do
    areawarp(ctx, "job_hunte", 50, 64, 129, 143, "job_hunte", 176, 22)
  end

  def on_event("OnTimer197000", ctx) do
    ctx
    |> donpcevent("Manager#hnt::OnReset")
    |> donpcevent("Waiting Room#hnt::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp announce(ctx, message), do: mapannounce(ctx, "job_hunte", message, 1)

  defp summon_all(ctx, mobs, event) do
    Enum.reduce(mobs, ctx, fn {mob_id, at}, acc ->
      summon_mob(acc, mob_id: mob_id, map: "job_hunte", at: at, event: event)
    end)
  end
end
