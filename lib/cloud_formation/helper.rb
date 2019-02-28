module CloudFormation
  module Helper
    def region
      ref("AWS::Region")
    end

    def tag(key, value="")
      {"Key" => key, "Value" => value}.compact
    end

    def ref(r)
      {"Ref" => r}
    end

    def cf_stack_name
      ref("AWS::StackName")
    end

    def join(sep, *vals)
      {"Fn::Join" => [sep, vals]}
    end

    def sub(s, mapping = {})
      if mapping.empty?
        {"Fn::Sub" => s}
      else
        {"Fn::Sub" => [s, mapping]}
      end
    end

    def select(index, list)
      {"Fn::Select" => [index, list]}
    end

    def azs
      {"Fn::GetAZs" => region}
    end

    def get_attr(*path)
      {"Fn::GetAtt" => path}
    end
  end
end
