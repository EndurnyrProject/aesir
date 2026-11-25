defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.ExperimentTube do
  @moduledoc """
  An experiment tube hides an oval and a passage out of the cube room.

  ## Behavior

  - Opens the tube with the black key and reveals a passage with a laboratory permit.

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
        map: "lhz_cube",
        x: 224,
        y: 197,
        dir: 0,
        sprite: 111,
        name: "Experiment Tube",
        scope: :shared,
        unique_name: "Experiment Tube#cube"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret01, 0)

    cond do
      stage < 8 -> inspect_locked_tube(ctx)
      stage == 8 -> unlock_tube(ctx)
      stage == 9 -> describe_fissure(ctx, "artificial")
      get_char_var(ctx, :lhz_sincube, 0) == 10 -> use_permit(ctx)
      true -> describe_fissure(ctx, "articial")
    end
  end

  defp describe_tube(ctx) do
    ctx
    |> mes("^3355FFYou find a strange")
    |> mes("tube that seems to")
    |> mes("contain something.")
    |> mes("Underneath the tube is")
    |> mes("a thin plate with a keyhole")
    |> mes("and a card insertion slot.^000000")
    |> next()
    |> input(:string)
  end

  defp inspect_locked_tube(ctx) do
    {ctx, answer} = describe_tube(ctx)

    ctx
    |> set_local(:"input$", answer)
    |> mes("^3355FFNothing happened.")
    |> mes("You'll probably need")
    |> mes("to find the right key for")
    |> mes("the keyhole and the correct")
    |> mes("card to insert into the slot.^000000")
    |> close()
  end

  defp unlock_tube(ctx) do
    {ctx, answer} = describe_tube(ctx)
    ctx = set_local(ctx, :"input$", answer)

    ctx =
      if get_local(ctx, :"input$", "") == "Black Key" do
        ctx
        |> mes("^3355FFYou insert the Black Key")
        |> mes("into the keyhole, causing")
        |> mes("the experiment tube to open")
        |> mes("and reveal an ^000000Oval^3355FF which you")
        |> mes("you choose to take with you.^000000")
        |> set_char_var(:lhz_secret01, 9)
      else
        mes(ctx, "^3355FFNothing happened...^000000")
      end

    close(ctx)
  end

  defp describe_fissure(ctx, adjective) do
    ctx
    |> mes("^3355FFThis is where you")
    |> mes("obtained the ^000000Oval^3355FF.")
    |> mes("As you look around")
    |> mes("the tube's location,")
    |> mes("you notice an #{adjective}")
    |> mes("ground fissure which")
    |> mes("can probably open up...^000000")
    |> close()
  end

  defp use_permit(ctx) do
    {ctx, answer} =
      ctx
      |> mes("^3355FFThere is a narrow,")
      |> mes("rectangular card slot")
      |> mes("in front of the tube.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    cond do
      get_local(ctx, :"input$", "") != "Laboratory Permit" ->
        ctx |> mes("^3355FFNothing happened.^000000") |> close()

      Rathena.truthy?(count_item(ctx, 2657)) ->
        open_passage(ctx)

      true ->
        ctx |> mes("^3355FF..............") |> mes("Nothing happened.^000000") |> close()
    end
  end

  defp open_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou insert the")
      |> mes("Laboratory Permit")
      |> mes("into the slot and the")
      |> mes("man made fissure in the")
      |> mes("ground splits open, revealing")
      |> mes("an underground staircase.^000000")
      |> next()
      |> select(["Go downstairs", "Cancel"])

    if choice == 1 do
      ctx =
        ctx
        |> mes("^3355FFYou walk down")
        |> mes("the long flight")
        |> mes("of winding stairs...^000000")
        |> close2()
        |> set_char_var(:lhz_sincube, 0)
        |> set_char_var(:lhz_secret01, 0)
        |> set_char_var(:lhz_secret02, 0)
        |> set_char_var(:lhz_secret03, 0)

      ctx
      |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 512))
      |> warp("lhz_cube", 177, 13)
    else
      close(ctx)
    end
  end
end
