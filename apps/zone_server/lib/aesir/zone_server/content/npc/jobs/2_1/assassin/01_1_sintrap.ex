defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.M011Sintrap do
  @moduledoc """
  Booby trap on the Assassin job test floor that sends careless applicants back.

  ## Behavior

  - While the Beholder's traps are armed, announces the trapped player, resets the test
    progress, sends the player back, clears the test monsters, and reopens the standby room.

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
        x: 68,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "01_1::SinTrap",
        scope: :shared,
        unique_name: "SinTrap",
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 69,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "01_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 68,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "01_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 69,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "01_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 64,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "02_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 65,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "02_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 64,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "02_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 65,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "02_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 62,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "03_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 63,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "03_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 62,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "03_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 63,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "03_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 66,
        y: 170,
        dir: 0,
        sprite: -1,
        name: "04_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 67,
        y: 170,
        dir: 0,
        sprite: -1,
        name: "04_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 66,
        y: 171,
        dir: 0,
        sprite: -1,
        name: "04_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 67,
        y: 171,
        dir: 0,
        sprite: -1,
        name: "04_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 64,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "05_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 64,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "05_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 65,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "05_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 65,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "05_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 72,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "06_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 72,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "06_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 73,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "06_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 73,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "06_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 72,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "07_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 72,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "07_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 73,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "07_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 73,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "07_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 72,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "08_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 72,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "08_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 73,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "08_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 73,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "08_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 78,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "09_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 78,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "09_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 79,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "09_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 79,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "09_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 80,
        y: 172,
        dir: 0,
        sprite: -1,
        name: "10_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 81,
        y: 172,
        dir: 0,
        sprite: -1,
        name: "10_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 82,
        y: 172,
        dir: 0,
        sprite: -1,
        name: "10_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 83,
        y: 172,
        dir: 0,
        sprite: -1,
        name: "10_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 80,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "10_5",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 81,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "10_6",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 82,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "10_7",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 83,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "10_8",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 88,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "11_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 88,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "11_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 89,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "11_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 89,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "11_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "12_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "12_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "12_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "12_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 90,
        y: 164,
        dir: 0,
        sprite: -1,
        name: "13_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 90,
        y: 165,
        dir: 0,
        sprite: -1,
        name: "13_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 91,
        y: 164,
        dir: 0,
        sprite: -1,
        name: "13_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 91,
        y: 165,
        dir: 0,
        sprite: -1,
        name: "13_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 84,
        y: 160,
        dir: 0,
        sprite: -1,
        name: "14_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 85,
        y: 160,
        dir: 0,
        sprite: -1,
        name: "14_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 160,
        dir: 0,
        sprite: -1,
        name: "14_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 160,
        dir: 0,
        sprite: -1,
        name: "14_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 88,
        y: 160,
        dir: 0,
        sprite: -1,
        name: "14_5",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 89,
        y: 160,
        dir: 0,
        sprite: -1,
        name: "14_6",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 84,
        y: 161,
        dir: 0,
        sprite: -1,
        name: "14_7",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 85,
        y: 161,
        dir: 0,
        sprite: -1,
        name: "14_8",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 161,
        dir: 0,
        sprite: -1,
        name: "14_9",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 161,
        dir: 0,
        sprite: -1,
        name: "14_10",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 88,
        y: 161,
        dir: 0,
        sprite: -1,
        name: "14_11",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 89,
        y: 161,
        dir: 0,
        sprite: -1,
        name: "14_12",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "15_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 155,
        dir: 0,
        sprite: -1,
        name: "15_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "15_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 155,
        dir: 0,
        sprite: -1,
        name: "15_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 84,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "16_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 84,
        y: 151,
        dir: 0,
        sprite: -1,
        name: "16_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 85,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "16_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 85,
        y: 151,
        dir: 0,
        sprite: -1,
        name: "16_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 90,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "17_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 90,
        y: 151,
        dir: 0,
        sprite: -1,
        name: "17_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 91,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "17_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 91,
        y: 151,
        dir: 0,
        sprite: -1,
        name: "17_4",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 146,
        dir: 0,
        sprite: -1,
        name: "18_1",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 86,
        y: 147,
        dir: 0,
        sprite: -1,
        name: "18_2",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 146,
        dir: 0,
        sprite: -1,
        name: "18_3",
        scope: :shared,
        trigger: {0, 0}
      },
      %{
        map: "in_moc_16",
        x: 87,
        y: 147,
        dir: 0,
        sprite: -1,
        name: "18_4",
        scope: :shared,
        trigger: {0, 0}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_npc_var_of(ctx, "DisableTraps", "Beholder#ASNTEST", 0) < 1 do
      ctx
      |> mapannounce(
        "in_moc_16",
        "#{char_name(ctx, 0)}, you're trapped. You will be sent back.",
        1
      )
      |> set_char_var(:ASSIN_Q, 2)
      |> warp("in_moc_16", 19, 161)
      |> donpcevent("Beholder#ASNTEST::OnResetmob")
      |> donpcevent("Standby Room#ASNTEST::OnStart")
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)
end
