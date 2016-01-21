module CloudFormation
  module Helper
    def region
      ref("AWS::Region")
    end

    def tag(key, value)
      {"Key" => key, "Value" => value}
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

    def select(index, list)
      {"Fn::Select" => [index, list]}
    end

    def azs
      {"Fn::GetAZs" => region}
    end
  end
end
