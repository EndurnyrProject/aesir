defmodule Aesir.ZoneServer.Content.Npc.Functions.FSignseal do
  @moduledoc """
  Resolves attempts to break the seals holding Agrboda's soul.

  ## Behavior

  - Checks carried weapons and the supplied roll before granting a soul fragment.
  - Combines the fragments when the final seal is broken.

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

  import Aesir.ZoneServer.Script.Dsl, warn: false
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Callable rAthena global function; returns `{ctx, return_value}`."
  def call(ctx, args), do: scoped_call(ctx, args, &run/2)

  defp run(ctx, args) do
    ctx = set_local(ctx, :r, Enum.at(args, 0, 0))

    threshold =
      cond do
        Rathena.truthy?(count_item(ctx, 1558)) or
            Rathena.truthy?(count_item(ctx, 1963)) ->
          980

        Rathena.truthy?(count_item(ctx, 1227)) or
          Rathena.truthy?(count_item(ctx, 1228)) or
          Rathena.truthy?(count_item(ctx, 1240)) or
          Rathena.truthy?(count_item(ctx, 1241)) or
          Rathena.truthy?(count_item(ctx, 1962)) or
            Rathena.truthy?(count_item(ctx, 1813)) ->
          960

        Rathena.truthy?(count_item(ctx, 1719)) or
          Rathena.truthy?(count_item(ctx, 1130)) or
          Rathena.truthy?(count_item(ctx, 1133)) or
          Rathena.truthy?(count_item(ctx, 1223)) or
          Rathena.truthy?(count_item(ctx, 1229)) or
          Rathena.truthy?(count_item(ctx, 1231)) or
          Rathena.truthy?(count_item(ctx, 1413)) or
          Rathena.truthy?(count_item(ctx, 1814)) or
            Rathena.truthy?(count_item(ctx, 1242)) ->
          940

        Rathena.truthy?(count_item(ctx, 1131)) or
          Rathena.truthy?(count_item(ctx, 1230)) or
            Rathena.truthy?(count_item(ctx, 1232)) ->
          920

        Rathena.truthy?(count_item(ctx, 1132)) or
          Rathena.truthy?(count_item(ctx, 1134)) or
          Rathena.truthy?(count_item(ctx, 1233)) or
          Rathena.truthy?(count_item(ctx, 1234)) or
          Rathena.truthy?(count_item(ctx, 1235)) or
          Rathena.truthy?(count_item(ctx, 1414)) or
          Rathena.truthy?(count_item(ctx, 1523)) or
            Rathena.truthy?(count_item(ctx, 1236)) ->
          900

        Rathena.truthy?(count_item(ctx, 1237)) or
          Rathena.truthy?(count_item(ctx, 1524)) or
          Rathena.truthy?(count_item(ctx, 1525)) or
          Rathena.truthy?(count_item(ctx, 1557)) or
          Rathena.truthy?(count_item(ctx, 1415)) or
            Rathena.truthy?(count_item(ctx, 1964)) ->
          880

        Rathena.truthy?(count_item(ctx, 1135)) or
          Rathena.truthy?(count_item(ctx, 1140)) or
          Rathena.truthy?(count_item(ctx, 1141)) or
            Rathena.truthy?(count_item(ctx, 1527)) ->
          860

        Rathena.truthy?(count_item(ctx, 1164)) or
          Rathena.truthy?(count_item(ctx, 1165)) or
          Rathena.truthy?(count_item(ctx, 1467)) or
          Rathena.truthy?(count_item(ctx, 1138)) or
          Rathena.truthy?(count_item(ctx, 1139)) or
          Rathena.truthy?(count_item(ctx, 1224)) or
          Rathena.truthy?(count_item(ctx, 1225)) or
          Rathena.truthy?(count_item(ctx, 1416)) or
            Rathena.truthy?(count_item(ctx, 1526)) ->
          840

        Rathena.truthy?(count_item(ctx, 1305)) or
          Rathena.truthy?(count_item(ctx, 1720)) or
          Rathena.truthy?(count_item(ctx, 1136)) or
          Rathena.truthy?(count_item(ctx, 1137)) or
            Rathena.truthy?(count_item(ctx, 1166)) ->
          820

        Rathena.truthy?(count_item(ctx, 1261)) or
          Rathena.truthy?(count_item(ctx, 1528)) or
            Rathena.truthy?(count_item(ctx, 1167)) ->
          800

        Rathena.truthy?(count_item(ctx, 1364)) or
            Rathena.truthy?(count_item(ctx, 1913)) ->
          780

        Rathena.truthy?(count_item(ctx, 1170)) or
          Rathena.truthy?(count_item(ctx, 1468)) or
          Rathena.truthy?(count_item(ctx, 1168)) or
            Rathena.truthy?(count_item(ctx, 1169)) ->
          760

        Rathena.truthy?(count_item(ctx, 1365)) or
          Rathena.truthy?(count_item(ctx, 1366)) or
            Rathena.truthy?(count_item(ctx, 1473)) ->
          740

        Rathena.truthy?(count_item(ctx, 1367)) or
          Rathena.truthy?(count_item(ctx, 1368)) or
          Rathena.truthy?(count_item(ctx, 1466)) or
            Rathena.truthy?(count_item(ctx, 1469)) ->
          720

        Rathena.truthy?(count_item(ctx, 1369)) or
            Rathena.truthy?(count_item(ctx, 1470)) ->
          700

        Rathena.truthy?(count_item(ctx, 1722)) or
            Rathena.truthy?(count_item(ctx, 1471)) ->
          680

        Rathena.truthy?(count_item(ctx, 1363)) ->
          660

        Rathena.truthy?(count_item(ctx, 1530)) ->
          500

        true ->
          nil
      end

    cond do
      is_nil(threshold) ->
        ctx =
          ctx
          |> mes("^3355FFThe weapon you're holding")
          |> mes(
            "right now doesn't look like it has any chance of breaking this seal. You'll definitely need something"
          )
          |> mes("more powerful...^000000")
          |> close()

        throw({:script_end, ctx})

      get_local(ctx, :r, 0) < threshold ->
        seal_failure(ctx)

      true ->
        :ok
    end

    ctx =
      if Rathena.truthy?(Enum.at(args, 1, 0)) do
        ctx
        |> mes("^3355FFUpon obtaining the last piece")
        |> mes(
          "of Agrboda's soul, all four soul pieces emitted a strange light, rose to the air and combined into"
        )
        |> mes("a single transparent jewel.^000000")
        |> next()
        |> mes("^3355FFThe jewel floated")
        |> mes("down to your waiting")
        |> mes("hands, and you hear its")
        |> mes("voice speak directly into")
        |> mes("the depths of your heart...^000000")
        |> next()
        |> mes("[Agrboda's Soul]")
        |> mes("^333333I'm...")
        |> mes("I'm leaving my soul")
        |> mes("with you. Please guide")
        |> mes("me to the queen of the dead...^000000")
        |> delitem(7306, 3)
        |> set_char_var(:sign_q, 117)
        |> give_item(7307, 1)
      else
        ctx
        |> mes("^3355FFOnce you strike the seal,")
        |> mes(
          "it cracks open and a flash of mysterious light floods out of it. Inside of the seal, you find a very peculiar object...^000000"
        )
        |> next()
        |> mes("^3355FFYou have")
        |> mes("obtained a^6E7B8B")
        |> mes("Piece of Spirit^3355FF.^000000")
        |> give_item(7306, 1)
      end

    {ctx, nil}
  end

  defp seal_failure(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou hit the seal as hard")
      |> mes(
        "as you can with the weapon in your hand. However, the seal is merely shaken by the force of your blow. Perhaps you need something"
      )
      |> mes("more powerful to break the seal...^000000")
      |> close()

    throw({:script_end, ctx})
  end
end
